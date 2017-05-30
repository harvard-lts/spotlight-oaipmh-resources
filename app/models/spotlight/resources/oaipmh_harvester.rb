require 'oai'
require 'net/http'
require 'uri'
  
module Spotlight::Resources
  class OaipmhHarvester < Spotlight::Resource
    attr_accessor :set, :base_url, :mapping_file
    self.document_builder_class = Spotlight::Resources::OaipmhBuilder
            
    def oaipmh_harvests
      self.url = self.data[:base_url] + '?verb=ListRecords&metadataPrefix=mods&set=' + self.data[:set]
      client = OAI::Client.new self.data[:base_url]
      @oaipmh_harvests = client.list_records :set => self.data[:set], :metadata_prefix => 'mods'
    end
    
    def self.mapping_files
      if (Dir.exist?('public/uploads/modsmapping'))
        files = Dir.entries('public/uploads/modsmapping')
        files.delete(".")
        files.delete("..")
      else
        files = Array.new
      end
      
      files.insert(0, "New Mapping File")
      files.insert(0, "Default Mapping File")
      files
    end
  end
end
