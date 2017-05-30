require 'oai'
require 'mods'
#require 'carrierwave'

include OAI::XPath
include Spotlight::Resources::Exceptions
module Spotlight::Resources
  class OaipmhModsItem
    extend CarrierWave::Mount
    attr_reader :titles, :id
    attr_accessor :metadata, :itemurl
    mount_uploader :itemurl, Spotlight::ItemUploader
    def initialize(exhibit, converter)
      @solr_hash = {}
      @exhibit = exhibit
      @converter = converter
    end
    
    def to_solr
      add_document_id
      add_title
#      add_thumbnail_url
#      add_full_image_urls
      add_manifest_url
      solr_hash
    end
    
    def parse_mods_record()
      
      modsonly = xpath_first(metadata, "*[local-name()='mods']")
      #puts modsonly.to_s
      modsrecord = Mods::Record.new.from_str(modsonly.to_s, false)
      
      if (modsrecord.mods_ng_xml.record_info && modsrecord.mods_ng_xml.record_info.recordIdentifier)
        @id = modsrecord.mods_ng_xml.record_info.recordIdentifier.text 
      end
      
      begin
        @titles = modsrecord.full_titles
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
      
      @solr_hash = @converter.convert(modsrecord)
               

#            @titles = modsrecord.short_titles
#            #locations = modsrecord.mods_ng_xml.location.url
#            @full_urls = Array.new
#            @thumb_urls = Array.new
#            @iiif_images = Array.new
##            for location in locations
##              access = location.get_attribute("access")
##              @thumb_url = nil
##              @full_url = nil
##              if (access == "preview")
##                @thumb_url = location.text
##                @full_url = fetch_ids_uri(@thumb_url)
##              end
##              
##              if (!@full_url.nil? && @full_url.include?("view"))
##                @full_urls.push @full_url
##                @thumb_urls.push @thumb_url
##                iiif_image = transform_ids_uri_to_iiif_manifest(@full_url)
##                @iiif_images.push iiif_image
##              end
##            end
#            @id = modsrecord.mods_ng_xml.record_info.recordIdentifier.text  
#            @subjects = modsrecord.mods_ng_xml.subject.topic.map { |n| n.text } 
          end

#    def parse_mods_record(modsrecord)
#      @titles = modsrecord.short_titles
#      locations = modsrecord.mods_ng_xml.location.url
#      for location in locations
#        access = location.get_attribute("access")
#        @thumb_url = location.text
#        if (access == "preview")
#          @full_url = fetch_ids_uri(@thumb_url)
#          @manifest_url = transform_ids_uri_to_iiif_manifest(@full_url)
#        end
#      end
#    end
    
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
    
    def compound_id
      Digest::MD5.hexdigest("#{exhibit.id}-#{url}")
    end

    def add_document_id
      solr_hash[:id] = @id
    end
          
    def add_manifest_url
      #solr_hash[:content_metadata_iiif_manifest_ssm] = @iiif_images
    end

    def add_thumbnail_url
      #solr_hash[:thumbnail_url_ssm] = @full_urls
      solr_hash[:thumbnail_url_ssm] = "/uploads/spotlight/resources/upload/url/187/thumb_danceparty.png"
      solr_hash[:thumbnail_square_url_ssm] = "/uploads/spotlight/resources/upload/url/187/square_danceparty.png"
    end

    def add_full_image_urls
      #solr_hash[:full_image_url_ssm] = @full_urls
      solr_hash[:full_image_url_ssm] = '/uploads/spotlight/resources/upload/url/187/danceparty.png'
      solr_hash[:spotlight_full_image_width_ssm] = "1800"
      solr_hash[:spotlight_full_image_height_ssm] = "1800"
    end

    def add_title
      #solr_hash[:full_title_tesim] = @titles[0]
    end
    
#    def add_image_urls
#      solr_hash[tile_source_field] = image_urls
#    end
#          
#    def image_urls
#        @image_urls ||= resources.map do |resource|
#        next unless resource && !resource.service.empty?
#        image_url = resource.service['@id']
#        image_url << '/info.json' unless image_url.downcase.ends_with?('/info.json')
#        image_url
#      end
#    end
    
  end
end