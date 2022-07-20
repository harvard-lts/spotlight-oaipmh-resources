require 'oai'
require 'net/http'
require 'uri'
require_relative '../../../mailer/spotlight/harvesting_complete_mailer'
include Spotlight::Resources::Exceptions
# encoding: utf-8
module Spotlight::Resources
  ##
  # Process a CSV upload into new Spotlight::Resource::Upload objects
  class PerformHarvestsJob < ActiveJob::Base
    include Spotlight::JobTracking
    queue_as :default

    with_job_tracking(
      resource: ->(job) { job.arguments.first.dig(:harvester) },
      reports_on: ->(job) { job.arguments.first.dig(:harvester).exhibit },
      user: ->(job) { job.arguments.first.dig(:user) }
    )

    def perform(harvester:, user: nil)
      harvest_result = harvest(harvester)
      raise HarvestingFailedException if harvest_result[:total_errors].positive?

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + harvester.data[:set])
      job_tracker.append_log_entry(type: :info, exhibit: harvester.exhibit, message: "#{harvest_result[:total_items]} items successfully harvested")

      Spotlight::HarvestingCompleteMailer.harvest_indexed(harvester.data[:set], harvester.exhibit, user).deliver_now if user.present?
    rescue HarvestingFailedException => e
      mark_job_as_failed!
      harvest_result[:errored_ids].each do |id|
        job_tracker.append_log_entry(type: :error, exhibit: harvester.exhibit, message: id + ' did not index successfully')
      end

      Spotlight::HarvestingCompleteMailer.harvest_failed(harvester.data[:set], harvester.exhibit, user).deliver_now if user.present?
    end

    def harvest(harvester)
      mapping_file = nil
      if (!harvester.data[:mapping_file].eql?("Default Mapping File") && !harvester.data[:mapping_file].eql?("New Mapping File"))
        mapping_file = harvester.data[:mapping_file]
      end

      @oai_mods_converter = OaipmhModsConverter.new(harvester.data[:set], harvester.exhibit.slug, mapping_file)

      harvests = harvester.oaipmh_harvests
      resumption_token = harvests.resumption_token
      last_page_evaluated = false
      total_items = 0
      total_errors = 0
      errored_ids = []
      until (resumption_token.nil? && last_page_evaluated)
        #once we reach the last page
        if (resumption_token.nil?)
          last_page_evaluated = true
        end

        harvests.each do |record|
          @item = OaipmhModsItem.new(harvester.exhibit, @oai_mods_converter)

          @item.metadata = record.metadata
          @item.parse_mods_record
          begin
            @item_solr = @item.to_solr
            @item_sidecar = @item.sidecar_data

            @item.parse_subjects
            @item.parse_types
            repository_field_name = @oai_mods_converter.get_spotlight_field_name("repository_ssim")
            @item.process_images
            @item.uniquify_repos(repository_field_name)

            # Add clean resource for editing
            new_resource = OaiUpload.find_or_create_by(exhibit: harvester.exhibit, external_id: @item.id) do |new_r|
              new_r.data = @item_sidecar
            end
            new_resource.reindex_later
            total_items += 1
          rescue Exception => e
            Delayed::Worker.logger.add(Logger::ERROR, @item.id + ' did not index successfully')
            Delayed::Worker.logger.add(Logger::ERROR, e.message)
            Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
            total_errors += 1
            errored_ids << @item.id
          end
        end
        if (!resumption_token.nil?)
          harvests = harvester.resumption_oaipmh_harvests(resumption_token)
          resumption_token = harvests.resumption_token
        end
      end
      { total_items: total_items, total_errors: total_errors, errored_ids: errored_ids }
    end
  end
end
