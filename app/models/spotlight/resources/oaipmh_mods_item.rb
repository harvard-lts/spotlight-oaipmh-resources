require 'oai'
require 'mods'
#require 'carrierwave'

include OAI::XPath
include Spotlight::Resources::Exceptions
module Spotlight::Resources
  class OaipmhModsItem
    extend CarrierWave::Mount
    attr_reader :titles, :id
    attr_accessor :metadata, :itemurl, :sidecar_data
    mount_uploader :itemurl, Spotlight::ItemUploader
    def initialize(exhibit, converter, cna_config)
      @solr_hash = {}
      @exhibit = exhibit
      @converter = converter
      @catalog_url = nil
      @finding_aid_url = nil
      @cna_config = cna_config
    end
    
    def to_solr
      add_document_id
      solr_hash
    end
    
    def parse_mods_record()
        
      @modsrecord = Mods::Record.new.from_str(metadata.elements.to_a[0].to_s, false)
          
      if (@modsrecord.mods_ng_xml.record_info && @modsrecord.mods_ng_xml.record_info.recordIdentifier)
        @id = @modsrecord.mods_ng_xml.record_info.recordIdentifier.text 
      end
      
      begin
        @titles = @modsrecord.full_titles
      rescue NoMethodError
        @titles = nil
      end
      
      if (@titles.blank? && @id.blank?)
        raise InvalidModsRecord, "A mods record was found that has no title and no identifier."
      elsif (@titles.blank?)
        raise InvalidModsRecord, "Mods record " + @id + " must have a title.  This mods record was not updated in Spotlight."
      elsif (@id.blank?)
        raise InvalidModsRecord, "Mods record " + @titles[0] + "must have a title. This mods record was not updated in Spotlight."
      end  
      
      @solr_hash = @converter.convert(@modsrecord)
      @sidecar_data = @converter.sidecar_hash
   end
   
   #This pulls the catalog url from the Mods::Record item for OASIS items.  Using the Mods::Record paths fail for this
   #I suspect that the way the mods gem is written conflicts with the way we have our paths (relatedItem/relatedItem/relatedItem/location/url)
   def get_catalog_url()
     if (@catalog_url.nil?)
       node = @modsrecord.mods_ng_xml.related_item.xpath(@cna_config['HOLLIS_RECORD_XPATH'])
       if (!node.nil?)
         @catalog_url = node.text
       else
         @catalog_url = ""
       end   
     end
     @catalog_url
   end
   
  #This pulls the finding aid url from the Mods::Record item for OASIS items.  Using the Mods::Record paths fail for this
  #I suspect that the way the mods gem is written conflicts with the way we have our paths (relatedItem/relatedItem/relatedItem/location/url)
  def get_finding_aid()
     if (@finding_aid_url.nil?)
       node = @modsrecord.mods_ng_xml.related_item.xpath(@cna_config['FINDING_AID_XPATH'])
       if (!node.nil?)
         @finding_aid_url = node.text
       else
         @finding_aid_url = ""
       end
     end
     @finding_aid_url
   end


    
   # private
    
    attr_reader :solr_hash, :exhibit
    
    #Resolves urn-3 uris
    def fetch_ids_uri(uri_str)
      if (uri_str =~ /urn-3/)
        response = Net::HTTP.get_response(URI.parse(uri_str))['location']
      elsif (uri_str.include?('?'))
        uri_str = uri_str.slice(0..(uri_str.index('?')-1))
      else
        uri_str
      end
    end
    
    #Returns the uri for the iiif manifest
    def transform_ids_uri_to_iiif_manifest(ids_uri)
      #Strip of parameters
      uri = ids_uri.sub(/\?.+/, "")
      #Change /view/ to /iiif/
      uri = uri.sub(%r|/view/|, "/iiif/")
      #Append /info.json to end
      uri = uri + "/info.json"
    end
    
    def add_document_id
      solr_hash[:id] = @id
    end
  
  end
end