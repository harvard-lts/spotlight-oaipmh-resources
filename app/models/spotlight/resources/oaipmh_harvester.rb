require 'oai'
require 'net/http'
require 'uri'
  
module Spotlight::Resources
  class OaipmhHarvester < Spotlight::Resource
    
        
    attr_accessor :set, :base_url
    self.document_builder_class = Spotlight::Resources::OaipmhBuilder
            
    def oaipmh_harvests
      self.url = self.data[:base_url] + '?verb=ListRecords&metadataPrefix=mods&set=' + self.data[:set]
      client = OAI::Client.new self.data[:base_url]
      @oaipmh_harvests = client.list_records :set => self.data[:set], :metadata_prefix => 'mods'
    end
    
    
    
#    def document_builder
#            @document_builder ||= Spotlight::Resources::OaipmhBuilder.new(self)
#          end

    
#    def to_solr
#      @oaipmh_harvests = oaipmh_harvests
#      return to_enum(:to_solr) { 0 } unless block_given?
#
#      base_doc = super
#      i = 0
#      
#      @oaipmh_harvests.full.each do |record|
#        if (i < 5)
#        
#        modsonly = xpath_first(record.metadata, './/mods')
#        print modsonly.to_s
#        modsrecord = Mods::Record.new.from_str(modsonly.to_s)
#        item = OaipmhModsItem.new(exhibit)
#        item.parse_mods_record(modsrecord)
#        
#        item_solr = item.to_solr
#        yield base_doc.merge(item_solr) if item_solr.present?
#        i = i + 1
#        end
#      end
#    end
      
#    def parse_harvests()
#      response.full.each do |record|
#      modsonly = xpath_first(record.metadata, './/mods:mods')
#      
#      modsrecord = Mods::Record.new.from_str(modsonly.to_s)
#      
#      item = OaipmhModsItem.new
#      item.parse_mods_record(modsrecord)
#      end
#      #titles = modsrecord.short_titles
#      
#      #locations = modsrecord.mods_ng_xml.location.url
#    end
    
    #Resolves urn-3 uris
#    def fetch_ids_uri(uri_str)
#      if (uri_str =~ /urn-3/)
#        response = Net::HTTP.get_response(URI.parse(uri_str))['location']
#      else
#        uri_str
#      end
#    end
    
    #Returns the uri for the iiif manifest
#    def transform_ids_uri_to_iiif_manifest(ids_uri)
#      #Strip of parameters
#      uri = ids_uri.sub(/\?.+/, "")
#      #Change /view/ to /iiif/
#      uri = uri.sub(%r|/view/|, "/iiif/")
#      #Append /info.json to end
#      uri = uri + "/info.json"
#    end
  end
end
