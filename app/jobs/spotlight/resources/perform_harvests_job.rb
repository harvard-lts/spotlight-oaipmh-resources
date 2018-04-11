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
    
    before_perform do |job|
      job_log_entry = log_entry(job)
      job_log_entry.in_progress! if job_log_entry
    end
         
    #This happens when the job starts or is enqueued, not after it finishes.  Why?
    after_perform do |job|
      url, set, mapping, exhibit, user = job.arguments
      Delayed::Worker.logger.add(Logger::INFO, 'Harvesting complete for set ' +set)
      Spotlight::HarvestingCompleteMailer.harvest_indexed(set, exhibit, user).deliver_now
    end
    
    rescue_from(HarvestingFailedException) do |exception|
      url, set, mapping, exhibit, user = job.arguments
      Delayed::Worker.logger.add(Logger::ERROR, 'Harvesting Failed for set ' +set)
      Spotlight::HarvestingCompleteMailer.harvest_failed(set, exhibit, user).deliver_now
    end

    def perform(url, set, mapping_file, exhibit, _user, job_entry)
      harvester = Spotlight::Resources::OaipmhHarvester.create(
        url: url,
        data: {base_url: url,
              set: set,
              mapping_file: mapping_file,
              job_entry: job_entry},
        exhibit: exhibit)
        
      if !harvester.save_and_index
        raise HarvestingFailedException
      end 
    end
 
 private
    
    def log_entry(job)
        job.arguments[5] if job.arguments[5].is_a?(Spotlight::JobLogEntry)
    end
  
  end

end
