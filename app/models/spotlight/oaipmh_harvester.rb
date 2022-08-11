require 'oai'
require 'net/http'
require 'uri'

module Spotlight
  class OaipmhHarvester < ActiveRecord::Base
    belongs_to :exhibit

    attr_accessor :total_errors

    def self.mapping_files
      if (Dir.exist?('public/uploads/modsmapping'))
        files = Dir.entries('public/uploads/modsmapping')
        files.delete('.')
        files.delete('..')
      else
        files = Array.new
      end

      files.insert(0, 'New Mapping File')
      files.insert(0, 'Default Mapping File')
      files
    end

    def harvest_oai_items(job_tracker: nil, job_progress: nil)
      @total_errors = 0
      harvests = oaipmh_harvests
      resumption_token = harvests.resumption_token
      last_page_evaluated = false

      update_progress_total(job_progress)
      until resumption_token.nil? && last_page_evaluated
        last_page_evaluated = true if resumption_token.nil? # we've reached the last page

        harvests.each do |record|
          harvest_item(record, job_tracker, job_progress)
        end

        if resumption_token.present?
          harvests = resumption_oaipmh_harvests(resumption_token)
          resumption_token = harvests.resumption_token
          update_progress_total(job_progress) # set size can change mid-harvest
        end

        # Log an update every 100 records
        if (job_progress.progress % 100).zero?
          job_tracker.append_log_entry(type: :info, exhibit: exhibit, message: "#{job_progress.progress} of #{job_progress.total} (#{self.total_errors} errors)")
        end
      end
    end

    def harvest_item(record, job_tracker, job_progress)
      parsed_oai_item = Spotlight::Resources::OaipmhModsParser.new(exhibit, oai_mods_converter)

      parsed_oai_item.metadata = record.metadata
      parsed_oai_item.parse_mods_record
      parsed_oai_item.uppercase_unique_id
      parsed_oai_item.to_solr

      parsed_oai_item.search_id(exhibit.id)
      parsed_oai_item.parse_subjects
      parsed_oai_item.parse_types
      repository_field_name = oai_mods_converter.get_spotlight_field_name('repository_ssim')
      parsed_oai_item.process_images
      parsed_oai_item.uniquify_repos(repository_field_name)
      # Add clean resource for editing
      resource = Spotlight::Resources::OaipmhUpload.find_or_create_by(exhibit: exhibit, external_id: parsed_oai_item.id.upcase)
      resource.data = parsed_oai_item.sidecar_data
      # If the sidecar for a resource already exists, and new fields have been added between harvests, then
      # the new key(s) will not persist on the Solr document. To ensure all keys always update, merge in
      # the whole data hash if the sidecar already exists before indexing.
      if resource.solr_document_sidecars.present?
        sidecar = resource.solr_document_sidecars.first
        sidecar.data['configured_fields'].merge!(resource.data)
        sidecar.save!
        # Get the updated sidecar data into our local variable
        resource.solr_document_sidecars.map(&:reload)
      end
      resource.attach_image if Spotlight::Oaipmh::Resources.download_full_image
      resource.save_and_index

      job_progress&.increment
    rescue Exception => e
      error_msg = parsed_oai_item.id + ' did not index successfully'
      Delayed::Worker.logger.add(Logger::ERROR, error_msg)
      Delayed::Worker.logger.add(Logger::ERROR, e.message)
      Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
      if job_tracker.present?
        job_tracker.append_log_entry(type: :error, exhibit: exhibit, message: error_msg)
      end
      self.total_errors += 1
    end

    def oaipmh_harvests
      @oaipmh_harvests = client.list_records(set: set, metadata_prefix: 'mods')
    end

    def resumption_oaipmh_harvests(token)
      @oaipmh_harvests = client.list_records(resumption_token: token)
    end

    def complete_list_size
      client
        .list_identifiers(set: set, metadata_prefix: 'mods')
        .doc
        .get_elements('.//resumptionToken')
        &.first
        &.attributes
        &.[]('completeListSize')
        &.to_i || 0
    end

    def client
      @client ||= OAI::Client.new(base_url)
    end

    def oai_mods_converter
      @oai_mods_converter ||= Spotlight::Resources::OaipmhModsConverter.new(set, exhibit.slug, get_mapping_file)
    end

    def update_progress_total(job_progress)
      job_progress.total = complete_list_size
    end

    def get_mapping_file
      return if mapping_file.eql?('Default Mapping File') || mapping_file.eql?('New Mapping File')

      mapping_file
    end
  end
end
