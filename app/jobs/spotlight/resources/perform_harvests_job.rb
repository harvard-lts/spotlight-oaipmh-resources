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
    with_job_tracking(resource: ->(job) { job.arguments.first })

    attr_reader :harvester, :exhibit, :set, :user

    after_perform do |job|
      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + set)
      # TODO: where do "progress" and "@errors" come from?
      job_tracker.append_log_entry(type: :info, exhibit: exhibit, message: "#{progress.progress} of #{progress.total} (#{@errors} errors)")

      Spotlight::HarvestingCompleteMailer.harvest_indexed(set, exhibit, user).deliver_now
    end

    rescue_from(HarvestingFailedException) do |exception|
      job_tracker.append_log_entry(type: :error, exhibit: exhibit, message: exception.to_s)
      mark_job_as_failed!

      Spotlight::HarvestingCompleteMailer.harvest_failed(set, exhibit, user).deliver_now
    end

    def perform(harvester, user)
      @harvester = harvester
      @exhibit = harvester.exhibit
      @set = harvester.data[:set]
      @user = user

      if !harvester.save_and_index
        raise HarvestingFailedException
      end 
    end
  end
end
