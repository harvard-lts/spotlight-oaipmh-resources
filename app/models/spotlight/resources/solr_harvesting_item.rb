
include Spotlight::Resources::Exceptions
module Spotlight::Resources
  class SolrHarvestingItem
    attr_reader :titles, :id
    attr_accessor :metadata, :sidecar_data
    def initialize(exhibit, converter)
      @solr_hash = {}
      @exhibit = exhibit
      @converter = converter
    end
    
    def to_solr
      add_document_id
      solr_hash
    end
    
    def parse_record()
        
      if (!metadata['_id'].empty?)
        @id = metadata['_id'] 
        #Strip out all of the decimals
        @id = @id.gsub('.', '')
        @id = @exhibit.id.to_s + "-" + @id.to_s
      end
      
      @solr_hash = @converter.convert(metadata)
      @sidecar_data = @converter.sidecar_hash
   end
  
   # private
    
    attr_reader :solr_hash, :exhibit

    
    def add_document_id
      solr_hash[:id] = @id.to_s
    end
  
  end
end