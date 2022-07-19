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
    queue_as :default

    def perform(url: nil, set: nil, mapping_file: nil, exhibit: nil, harvester: nil, user: nil)
      harvester ||= Spotlight::Resources::OaipmhHarvester.create(
        url: url,
        data: {base_url: url,
              set: set,
              mapping_file: mapping_file},
        exhibit: exhibit)

      raise HarvestingFailedException if !OaipmhBuilder.new(harvester).to_solr

      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' + harvester.data[:set])
      Spotlight::HarvestingCompleteMailer.harvest_indexed(harvester.data[:set], harvester.exhibit, user).deliver_now
    rescue HarvestingFailedException
      Spotlight::HarvestingCompleteMailer.harvest_failed(harvester.data[:set], harvester.exhibit, user).deliver_now
    end
  end
end
