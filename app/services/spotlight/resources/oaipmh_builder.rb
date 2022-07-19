module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class OaipmhBuilder
      attr_reader :resource

      def initialize(resource)
        @resource = resource
      end

      def to_solr
        mapping_file = nil
        if (!resource.data[:mapping_file].eql?("Default Mapping File") && !resource.data[:mapping_file].eql?("New Mapping File"))
          mapping_file = resource.data[:mapping_file]
        end

        @oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)

        harvests = resource.oaipmh_harvests
        resumption_token = harvests.resumption_token
        last_page_evaluated = false
        total_items = 0
        total_errors = 0
        errored_ids = []
        until (resumption_token.nil? && last_page_evaluated)
          #once we reach the last page
          if (resumption_token.nil?)
            last_page_evaluated = true
          end

          harvests.each do |record|
            @item = OaipmhModsItem.new(resource.exhibit, @oai_mods_converter)

            @item.metadata = record.metadata
            @item.parse_mods_record()
            begin
              @item_solr = @item.to_solr
              @item_sidecar = @item.sidecar_data

              parse_subjects()
              parse_types()

              repository_field_name = @oai_mods_converter.get_spotlight_field_name("repository_ssim")

              process_images()
              
              uniquify_repos(repository_field_name)

              #Add clean resource for editing
              new_resource = OaiUpload.find_or_create_by(exhibit: resource.exhibit, external_id: @item.id) do |new_r|
                new_r.data = @item_sidecar
              end
              new_resource.reindex_later
              total_items += 1
            rescue Exception => e
              Delayed::Worker.logger.add(Logger::ERROR, @item.id + ' did not index successfully')
              Delayed::Worker.logger.add(Logger::ERROR, e.message)
              Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
              total_errors += 1
              errored_ids << @item.id
            end
          end
          if (!resumption_token.nil?)
            harvests = resource.resumption_oaipmh_harvests(resumption_token)
            resumption_token = harvests.resumption_token
          end
        end
        { total_items: total_items, total_errors: total_errors, errored_ids: errored_ids }
      end

      #Adds the solr image info
      def add_image_info(fullurl, thumb, square)
          if (!thumb.nil?)
            @item_solr[:thumbnail_url_ssm] = thumb
          end
        
          if (!fullurl.nil?)
            if (!square.nil?)
              square = File.dirname(fullurl) + '/square_' + File.basename(fullurl)
            end
            @item_solr[:thumbnail_square_url_ssm] = square
            @item_solr[:full_image_url_ssm] = fullurl
          end
                
      end
      
      #Adds the solr image dimensions
      def add_image_dimensions(file)
        if (!file.nil?)
          dimensions = ::MiniMagick::Image.open(file)[:dimensions]
          @item_solr[:spotlight_full_image_width_ssm] = dimensions.first
          @item_solr[:spotlight_full_image_height_ssm] = dimensions.last
        end
      end

private   

      def parse_subjects()
        subject_field_name = @oai_mods_converter.get_spotlight_field_name("subjects_ssim")
        if (@item_solr.key?(subject_field_name) && !@item_solr[subject_field_name].nil?)
          #Split on |
          subjects = @item_solr[subject_field_name].split('|')
          @item_solr[subject_field_name] = subjects
          @item_sidecar["subjects_ssim"] = subjects
        end
      end
      
      def parse_types()
        type_field_name = @oai_mods_converter.get_spotlight_field_name("type_ssim")
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
          thumburl = transform_ids_uri_to_iiif(thumburl)
          @item_solr['thumbnail_url_ssm'] =  thumburl
        end
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
        start_date_name = @oai_mods_converter.get_spotlight_field_name("start-date_tesim")
        end_date_name = @oai_mods_converter.get_spotlight_field_name("end-date_tesim")
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
    
      #Returns the uri for the iiif
      def transform_ids_uri_to_iiif(ids_uri)
        #Strip of parameters
        uri = ids_uri.sub(/\?.+/, "")
        #Change /view/ to /iiif/
        uri = uri.sub(%r|/view/|, "/iiif/")
        #Append /info.json to end
        uri = uri + "/full/180,/0/native.jpg"
      end

    end
  end
end
