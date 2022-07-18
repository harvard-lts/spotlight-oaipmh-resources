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

    queue_as :import
    with_job_tracking(resource: ->(job) { job.arguments.first })

    def perform(url: nil, set: nil, mapping_file: nil, exhibit: nil, harvester: nil, user: nil)
      harvester ||= Spotlight::Resources::OaipmhHarvester.create(
        url: url,
        data: {base_url: url,
              set: set,
              mapping_file: mapping_file},
        exhibit: exhibit)

      raise HarvestingFailedException if !OaipmhBuilder.new(harvester).create_or_update_items&.first

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + harvester.data[:set])
      # TODO: where do "progress" and "@errors" come from?
      job_tracker.append_log_entry(type: :info, exhibit: harvester.exhibit, message: "#{progress.progress} of #{progress.total} (#{@errors} errors)")

      Spotlight::HarvestingCompleteMailer.harvest_indexed(harvester.data[:set], harvester.exhibit, user).deliver_now
    rescue HarvestingFailedException => e
      job_tracker.append_log_entry(type: :error, exhibit: harvester.exhibit, message: e.to_s)
      mark_job_as_failed!

      Spotlight::HarvestingCompleteMailer.harvest_failed(harvester.data[:set], harvester.exhibit, user).deliver_now
    end
  end
end
