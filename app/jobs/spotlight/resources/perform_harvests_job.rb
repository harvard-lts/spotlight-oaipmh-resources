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

    attr_reader :harvester, :exhibit, :set, :user, :oai_mods_converter

    with_job_tracking(
      resource: ->(job) { job.arguments.first.dig(:harvester) },
      reports_on: ->(job) { job.arguments.first.dig(:harvester).exhibit },
      user: ->(job) { job.arguments.first.dig(:user) }
    )

    def perform(harvester:, user: nil)
      @harvester = harvester
      @exhibit = harvester.exhibit
      @set = harvester.set
      @user = user
      @oai_mods_converter = OaipmhModsConverter.new(set, exhibit.slug, mapping_file)

      harvest_oai_items
      raise HarvestingFailedException if @total_errors.positive?

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + set)
      Spotlight::HarvestingCompleteMailer.harvest_indexed(set, exhibit, user).deliver_now if user.present?
    rescue HarvestingFailedException => e
      mark_job_as_failed!
      Spotlight::HarvestingCompleteMailer.harvest_failed(set, exhibit, user).deliver_now if user.present?
    end

    def harvest_oai_items
      harvests = harvester.oaipmh_harvests
      resumption_token = harvests.resumption_token
      last_page_evaluated = false
      @total_errors = 0

      update_progress_total
      until resumption_token.nil? && last_page_evaluated
        last_page_evaluated = true if resumption_token.nil? # we've reached the last page

        harvests.each do |record|
          harvest_item(record)
        end

        if resumption_token.present?
          harvests = harvester.resumption_oaipmh_harvests(resumption_token)
          resumption_token = harvests.resumption_token
          update_progress_total # set size can change mid-harvest
          job_tracker.append_log_entry(type: :info, exhibit: exhibit, message: "#{progress.progress} of #{progress.total} (#{@total_errors} errors)")
        end
      end
    end

    def harvest_item(record)
      item = OaipmhModsItem.new(exhibit, oai_mods_converter)

      item.metadata = record.metadata
      item.parse_mods_record
      item.uppercase_unique_id
      item.to_solr
      item_sidecar = item.sidecar_data

      item.parse_subjects
      item.parse_types
      repository_field_name = oai_mods_converter.get_spotlight_field_name('repository_ssim')
      item.process_images
      item.uniquify_repos(repository_field_name)

      # Add clean resource for editing
      
      new_resource = OaiUpload.find_or_create_by(exhibit: exhibit, external_id: item.id.upcase) do |new_r|
        new_r.data = item_sidecar
      end
      new_resource.attach_image if Spotlight::Oaipmh::Resources.download_full_image
      new_resource.save_and_index

      progress&.increment
    rescue Exception => e
      error_msg = item.id + ' did not index successfully'
      Delayed::Worker.logger.add(Logger::ERROR, error_msg)
      Delayed::Worker.logger.add(Logger::ERROR, e.message)
      Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
      job_tracker.append_log_entry(type: :error, exhibit: exhibit, message: error_msg)
      @total_errors += 1
    end

    def update_progress_total
      progress.total = harvester.complete_list_size
    end

    def mapping_file
      return if harvester.mapping_file.eql?('Default Mapping File') || harvester.mapping_file.eql?('New Mapping File')

      harvester.mapping_file
    end
  end
end
