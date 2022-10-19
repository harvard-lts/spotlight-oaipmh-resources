require 'net/http'
require 'uri'

module Spotlight
  class SolrHarvester < Harvester
    ROW_COUNT = 50

    alias_attribute :mapping_file, :solr_mapping_file

    def self.mapping_files
      super('solrmapping')
    end

    def get_harvests
      @solr_connection = RSolr.connect :url => @url  
      response = @solr_connection.paginate 0, ROW_COUNT, 'select', :params => {:q => '*:*', :wt => 'json'}
    end

    def paginate (page)
      if (@solr_connection.nil?)
        @solr_connection = RSolr.connect :url => @url  
      end
      response = @solr_connection.paginate page, ROW_COUNT, 'select', :params => {:q => '*:*', :wt => 'json'}
    end
  end
end
