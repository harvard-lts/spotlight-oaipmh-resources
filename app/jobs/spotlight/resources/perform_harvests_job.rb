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
      resource: ->(job) { job.arguments.first },
      reports_on: ->(job) { job.arguments.first.exhibit },
      user: ->(job) { job.arguments.second }
    )

    def perform(harvester, user)
      harvest_result = OaipmhBuilder.new(harvester).to_solr
      raise HarvestingFailedException if harvest_result[:total_errors].positive?

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + harvester.data[:set])
      job_tracker.append_log_entry(type: :info, exhibit: harvester.exhibit, message: "#{harvest_result[:total_items]} items successfully harvested")

      Spotlight::HarvestingCompleteMailer.harvest_indexed(harvester.data[:set], harvester.exhibit, user).deliver_now
    rescue HarvestingFailedException => e
      mark_job_as_failed!
      harvest_result[:errored_ids].each do |id|
        job_tracker.append_log_entry(type: :error, exhibit: harvester.exhibit, message: id + ' did not index successfully')
      end

      Spotlight::HarvestingCompleteMailer.harvest_failed(harvester.data[:set], harvester.exhibit, user).deliver_now
    end
  end
end
