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

    PERCENT_FAILURE_THRESHOLD = 0.5

    attr_reader :harvester, :exhibit, :set, :user, :total_errors

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
      @sidecar_ids = harvester.harvest_oai_items(job_tracker: job_tracker, job_progress: progress)
      @total_errors = harvester.total_errors

      if Spotlight::Oaipmh::Resources.use_solr_document_urns
        urn_errors = Spotlight::Resources::LoadUrnsJob.perform_now(job_tracker: job_tracker, sidecar_ids: sidecar_ids, user: user)
        mark_job_as_failed! if (urn_errors.to_f / @sidecar_ids.size.to_f) > PERCENT_FAILURE_THRESHOLD
        @total_errors += urn_errors
      end

      mark_job_as_failed! if (harvester.total_errors.to_f / (harvester.total_errors + harvester.total_successes).to_f) > PERCENT_FAILURE_THRESHOLD
    end

    after_perform do |job|
      Delayed::Worker.logger.add(Logger::INFO, "Harvesting complete for set #{job.set}")
      Spotlight::HarvestingCompleteMailer.harvest_set_completed(job).deliver_now if job.user.present?
    end
  end
end
