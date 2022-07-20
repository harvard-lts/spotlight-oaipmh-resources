require 'oai'
require 'net/http'
require 'uri'
  
module Spotlight::Resources
  class OaipmhHarvester < Spotlight::Resource
    attr_accessor :set, :base_url, :mapping_file

    def self.indexing_pipeline
      @indexing_pipeline ||= super.dup.tap do |pipeline|
        # if, say, you wanted to feed the transform with multiple source documents (here, by calling the `#iiif_manifest` method on the DlmeJson instance); previously, the #to_solr method of the document builder would have done this extraction
        # pipeline.sources = [Spotlight::Etl::Sources::SourceMethodSource(:iiif_manifests)]
        pipeline.transforms = [
          ->(data, p) { PerformHarvestsJob.perform_later(harvester: p.source) }
        ]
      end
    end

    def oaipmh_harvests
      self.url = self.data[:base_url] + '?verb=ListRecords&metadataPrefix=mods&set=' + self.data[:set]
      @client = OAI::Client.new self.data[:base_url]
      @oaipmh_harvests = @client.list_records :set => self.data[:set], :metadata_prefix => 'mods'
    end

    def resumption_oaipmh_harvests (token)
      @oaipmh_harvests = @client.list_records :resumption_token => token
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
