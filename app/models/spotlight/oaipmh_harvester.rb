require 'oai'
require 'net/http'
require 'uri'

module Spotlight
  class OaipmhHarvester < Harvester
    alias_attribute :mapping_file, :mods_mapping_file

    def self.mapping_files
      super('modsmapping')
    end

    def harvest_items(job_tracker: nil, job_progress: nil)
      self.total_errors = 0
      @sidecar_ids = []
      harvests = oaipmh_harvests
      resumption_token = harvests.resumption_token
      last_page_evaluated = false
      if !resumption_token.nil?
        Delayed::Worker.logger.add(Logger::INFO, "UPDATED resumption token is #{resumption_token}")
      else
        Delayed::Worker.logger.add(Logger::INFO, "nil resumption token")
      end

      update_progress_total(job_progress)
      until resumption_token.nil? && last_page_evaluated
        last_page_evaluated = true if resumption_token.nil? # we've reached the last page

        harvests.each do |record|
          harvest_item(record, job_tracker, job_progress)
        end

        if resumption_token.present?
          Delayed::Worker.logger.add(Logger::INFO, "IN the setting of resumption token is #{resumption_token}")
          old_rt = resumption_token
          harvests = resumption_oaipmh_harvests(resumption_token)
          if harvests.blank?
            Delayed::Worker.logger.add(Logger::INFO, "the harvest response was blank")
            harvests = resumption_oaipmh_harvests(resumption_token)
          end
          resumption_token = harvests.resumption_token
          if !resumption_token.nil?
            Delayed::Worker.logger.add(Logger::INFO, "UPDATED resumption token is #{resumption_token}")
          else
            Delayed::Worker.logger.add(Logger::INFO, "resump didnt set one, nil resumption token")
            Delayed::Worker.logger.add(Logger::INFO, "resump records we got back before nil")
            Delayed::Worker.logger.add(Logger::INFO, "resump this si the harvest doc #{harvests.@doc}")
            if (job_progress.progress != job_progress.total)
              while job_progress.total == 0
                Delayed::Worker.logger.add(Logger::INFO, "resump job progress was 0")
                job_progress.total = complete_list_size
              end
              Delayed::Worker.logger.add(Logger::INFO, "resumption progress is #{job_progress.progress}, total is #{job_progress.total}")
              Delayed::Worker.logger.add(Logger::INFO, "resumption need to set a token")
              harvests = resumption_oaipmh_harvests(old_rt)
              resumption_token = harvests.resumption_token
            end
          end
          update_progress_total(job_progress) # set size can change mid-harvest
        end

        # Log an update every 100 records
        if (job_progress.progress % 100).zero?
          job_tracker.append_log_entry(type: :info, exhibit: exhibit, message: "#{job_progress.progress} of #{job_progress.total} (#{self.total_errors} errors)")
          if !resumption_token.nil?
            Delayed::Worker.logger.add(Logger::INFO, "100 record update UPDATED resumption token is #{resumption_token}")
          else
            Delayed::Worker.logger.add(Logger::INFO, "nil resumption token 100 record update")
          end
        end
      end
      @sidecar_ids
    end

    def harvest_item(record, job_tracker, job_progress)
      parsed_oai_item = Spotlight::Resources::OaipmhModsParser.new(exhibit, oai_mods_converter)

      parsed_oai_item.metadata = record.metadata
      parsed_oai_item.parse_mods_record
      # At this point, we know the candidate for the sidecar's document_id.  This will be used in
      # the Spotlight::Resources::LoadUrnsJob
      @sidecar_ids << parsed_oai_item.id if Spotlight::Oaipmh::Resources.use_solr_document_urns

      parsed_oai_item.uppercase_unique_id
      parsed_oai_item.to_solr

      parsed_oai_item.search_id(exhibit.id)
      parsed_oai_item.parse_subjects
      parsed_oai_item.parse_types
      repository_field_name = oai_mods_converter.get_spotlight_field_name('repository_ssim')
      parsed_oai_item.uniquify_repos(repository_field_name)
      parsed_oai_item.process_images

      # Create clean resource for editing
      resource = Spotlight::Resources::OaipmhUpload.find_or_initialize_by(exhibit: exhibit, external_id: parsed_oai_item.id.upcase)
      resource.data = parsed_oai_item.item_sidecar
      resource.attach_image if Spotlight::Oaipmh::Resources.download_full_image
      # The resource's sidecar is set up correctly the first time; nothing special is required
      if resource.solr_document_sidecars.blank?
        resource.save_and_index
      else
        # As of Spotlight v3.3.0, if a resource already has a sidecar, the sidecar (and thus the data in Solr)
        # will not update unless done explicitly. The sidecar's #data is organized differently than the
        # resource's #data, so we can't just copy it over from the resource directly.
        resource.save!
        sidecar = resource.solr_document_sidecars.first
        sidecar.data = parsed_oai_item.organize_item_sidecar_data
        sidecar.save!
        # Get the updated sidecar into our local variable to ensure proper indexing
        resource.reload.reindex_later
      end

      job_progress&.increment
    rescue Exception => e
      handle_item_harvest_error(e, parsed_oai_item, job_tracker)
    end

    def oaipmh_harvests
      @oaipmh_harvests = client.list_records(set: set, metadata_prefix: 'mods')
      #Delayed::Worker.logger.add(Logger::INFO, "the ORIGINAL OAI list is #{oaipmh_harvests}")
    end

    def resumption_oaipmh_harvests(token)
      Delayed::Worker.logger.add(Logger::INFO, "trying to resume harvest token is #{token}")
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
  end
end
