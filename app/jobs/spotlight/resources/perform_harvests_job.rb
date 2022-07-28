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

    attr_reader :harvester, :exhibit, :set, :user

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

      harvester.harvest_oai_items(job_tracker: job_tracker, job_progress: progress)
      raise HarvestingFailedException if harvester.total_errors.positive?

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + set)
      Spotlight::HarvestingCompleteMailer.harvest_indexed(set, exhibit, user).deliver_now if user.present?
    rescue HarvestingFailedException => e
      mark_job_as_failed!
      Spotlight::HarvestingCompleteMailer.harvest_failed(set, exhibit, user).deliver_now if user.present?
    end
  end
end
