require 'oai'
require 'net/http'
require 'uri'
  
module Spotlight
  class OaipmhHarvester < ActiveRecord::Base
    belongs_to :exhibit

    def oaipmh_harvests
      @oaipmh_harvests = client.list_records(set: set, metadata_prefix: 'mods')
    end

    def resumption_oaipmh_harvests(token)
      @oaipmh_harvests = client.list_records(resumption_token: token)
    end

    def complete_list_size
      client
        .list_identifiers(set: set, metadata_prefix: 'mods')
        .doc
        .get_elements('.//resumptionToken')
        .first
        .attributes['completeListSize']
        .to_i
    end

    def client
      @client ||= OAI::Client.new(base_url)
    end

    def self.mapping_files
      if (Dir.exist?('public/uploads/modsmapping'))
        files = Dir.entries('public/uploads/modsmapping')
        files.delete('.')
        files.delete('..')
      else
        files = Array.new
      end

      files.insert(0, 'New Mapping File')
      files.insert(0, 'Default Mapping File')
      files
    end
  end
end
