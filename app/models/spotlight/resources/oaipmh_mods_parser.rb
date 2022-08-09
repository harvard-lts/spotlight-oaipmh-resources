require 'oai'
require 'mods'
#require 'carrierwave'

include OAI::XPath
include Spotlight::Resources::Exceptions
module Spotlight::Resources
  class OaipmhModsParser
    extend CarrierWave::Mount
    attr_reader :titles, :id, :solr_hash, :exhibit
    attr_accessor :metadata, :sidecar_data
    #attr_accessor :metadata, :itemurl, :sidecar_data
    #mount_uploader :itemurl, Spotlight::ItemUploader
    def initialize(exhibit, converter)
      @solr_hash = {}
      @exhibit = exhibit
      @converter = converter
    end

    def to_solr
      add_document_id
      @item_solr = solr_hash
      @item_sidecar = sidecar_data

      @item_solr
    end

    def parse_mods_record
      @modsrecord = Mods::Record.new.from_str(metadata.elements.to_a[0].to_s)

      if (@modsrecord.mods_ng_xml.record_info && @modsrecord.mods_ng_xml.record_info.recordIdentifier)
        @id = @modsrecord.mods_ng_xml.record_info.recordIdentifier.text
        #Strip out all of the decimals
        @id = @id.gsub('.', '')
        @id = @exhibit.id.to_s + "-" + @id.to_s
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

    def uppercase_unique_id
      # check if the unique ID has a lowercase letter in it
      if (solr_hash["unique-id_tesim"] =~ /[a-z]/).present?
        # make all URNs uppercase
        solr_hash["unique-id_tesim"] = solr_hash["unique-id_tesim"].upcase!
      end
    end

    def search_id
      # strip out decimal and store in hashes
      solr_hash['search-id_tesim'] = sidecar_data['search-id_tesim'] = solr_hash['unique-id_tesim'].gsub('.', '')
    end

    def add_document_id
      solr_hash[:id] = @id.to_s
    end

    def parse_subjects()
      subject_field_name = @converter.get_spotlight_field_name("subjects_ssim")
      if (@item_solr.key?(subject_field_name) && !@item_solr[subject_field_name].nil?)
        #Split on |
        subjects = @item_solr[subject_field_name].split('|')
        @item_solr[subject_field_name] = subjects
        @item_sidecar["subjects_ssim"] = subjects
      end
    end

    def parse_types()
      type_field_name = @converter.get_spotlight_field_name("type_ssim")
      if (@item_solr.key?(type_field_name) && !@item_solr[type_field_name].nil?)
        #Split on |
        types = @item_solr[type_field_name].split('|')
        @item_solr[type_field_name] = types
        @item_sidecar["type_ssim"] = types
      end
    end

    def process_images()
      if (@item_solr.key?('thumbnail_url_ssm') && !@item_solr['thumbnail_url_ssm'].blank? && !@item_solr['thumbnail_url_ssm'].eql?('null'))
        thumburl = fetch_ids_uri(@item_solr['thumbnail_url_ssm'])
        thumburl = transform_ids_uri_to_iiif(thumburl) if Spotlight::Oaipmh::Resources.use_iiif_images
        @item_solr['thumbnail_url_ssm'] =  thumburl
        @item_sidecar['thumbnail_url_ssm'] = thumburl
      end

      if(@item_solr['full_image_url_ssm'].present? && !@item_solr['full_image_url_ssm'].eql?('null') && !Spotlight::Oaipmh::Resources.download_full_image)
        full_url = transform_to_view_urls(@item_solr['full_image_url_ssm'])
        @item_solr['full_image_url_ssm'] = full_url
        @item_sidecar['full_image_url_ssm'] = full_url
      end
    end

    def transform_to_view_urls(url_string)
      url_string.gsub!(/\?.*$/, '')
      parts = url_string.split('/')
      tail = parts.last
      tail_parts = tail.split(':')
      if tail != tail_parts.join('')
        tail_parts[3] = "VIEW"
        tail = tail_parts.join(':')
        parts[-1] = tail
        url_string = parts.join('/')
      end
      url_string
    end

    def uniquify_repos(repository_field_name)
      #If the repository exists, make sure it has unique values
      if (@item_solr.key?(repository_field_name) && !@item_solr[repository_field_name].blank?)
        repoarray = @item_solr[repository_field_name].split("|")
        repoarray = repoarray.uniq
        repo = repoarray.join("|")
        @item_solr[repository_field_name] = repo
        @item_sidecar["repository_ssim"] = repo
      end
    end

    def uniquify_dates()
      start_date_name = @converter.get_spotlight_field_name("start-date_tesim")
      end_date_name = @converter.get_spotlight_field_name("end-date_tesim")
      start_date = @item_solr[start_date_name]
      end_date = @item_solr[end_date_name]
      if (!start_date.blank?)
        datearray = @item_solr[start_date_name].split("|")
        dates = datearray.join("|")
        @item_solr[start_date_name] = dates
        @item_sidecar["start-date_tesim"] = dates
      end
      if (!end_date.blank?)
        datearray = @item_solr[end_date_name].split("|")
        dates = datearray.join("|")
        @item_solr[end_date_name] = dates
        @item_sidecar["end-date_tesim"] = dates
      end
    end

    def parse_object_id
      object_id_name = @converter.get_spotlight_field_name('object_id_ssi')
      # TODO: full_image_url_ssm is not the correct value we need, replace with the correct value
      parsed_object_id = @item_solr['full_image_url_ssm']

      @item_solr[object_id_name] = parsed_object_id
      @item_sidecar['object_id_ssi'] = parsed_object_id
    end

    # Resolves urn-3 uris
    def fetch_ids_uri(uri_str)
      if (uri_str =~ /urn-3/)
        response = Net::HTTP.get_response(URI.parse(uri_str))['location']
      elsif (uri_str.include?('?'))
        uri_str = uri_str.slice(0..(uri_str.index('?')-1))
      else
        uri_str
      end
    end

    # Returns the uri for the iiif
    def transform_ids_uri_to_iiif(ids_uri)
      #Strip of parameters
      uri = ids_uri.sub(/\?.+/, "")
      #Change /view/ to /iiif/
      uri = uri.sub(%r|/view/|, "/iiif/")
      #Append /info.json to end
      uri = uri + "/full/300,/0/native.jpg"
    end
  end
end
