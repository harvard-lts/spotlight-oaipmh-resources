module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class OaipmhBuilder < Spotlight::SolrDocumentBuilder
      
      def to_solr
        begin
        return to_enum(:to_solr) { 0 } unless block_given?

        base_doc = super
          
           
        mapping_file = nil
        if (!resource.data[:mapping_file].eql?("Default Mapping File") && !resource.data[:mapping_file].eql?("New Mapping File"))
          mapping_file = resource.data[:mapping_file]
        end
        
        @oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
        
        count = 0
        harvests = resource.oaipmh_harvests
        resumption_token = harvests.resumption_token
        last_page_evaluated = false
        until (resumption_token.nil? && last_page_evaluated)
          #once we reach the last page
          if (resumption_token.nil?)
            last_page_evaluated = true
          end
          harvests.each do |record|
            @item = OaipmhModsItem.new(exhibit, @oai_mods_converter)
            
            @item.metadata = record.metadata
            @item.parse_mods_record()
            begin
              @item_solr = @item.to_solr
              @item_sidecar = @item.sidecar_data
              
              repository_field_name = @oai_mods_converter.get_spotlight_field_name("repository_ssim")
              
              process_images()

              #uniquify_repos(repository_field_name)
              
              #Add the sidecar info for editing
              sidecar ||= resource.document_model.new(id: @item.id).sidecar(resource.exhibit) 
              sidecar.update(data: @item_sidecar)
              yield base_doc.merge(@item_solr) if @item_solr.present?
              
              count = count + 1
              curtime = Time.zone.now
              resource.get_job_entry.update(job_item_count: count, end_time: curtime)

            rescue Exception => e
              Delayed::Worker.logger.add(Logger::ERROR, @item.id + ' did not index successfully')
              Delayed::Worker.logger.add(Logger::ERROR, e.message)
              Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
            end
          end
          if (!resumption_token.nil?)
            harvests = resource.resumption_oaipmh_harvests(resumption_token)
            resumption_token = harvests.resumption_token
          end
        end
        rescue
          resource.get_job_entry.failed!
          raise
        end
        resource.get_job_entry.succeeded!
      end

private   

      
      def process_images()
        if (@item_solr.key?('thumbnail_url_ssm') && !@item_solr['thumbnail_url_ssm'].blank? && !@item_solr['thumbnail_url_ssm'].eql?('null'))           
          thumburl = fetch_ids_uri(@item_solr['thumbnail_url_ssm'])
          thumburl = transform_ids_uri_to_iiif(thumburl)
          @item_solr['thumbnail_url_ssm'] =  thumburl
        end
        if (@item_solr.key?('full_image_url_ssm') && !@item_solr['full_image_url_ssm'].blank? && !@item_solr['full_image_url_ssm'].eql?('null'))           
          fullurl = fetch_ids_uri(@item_solr['full_image_url_ssm'])
          #if it is IDS, then add ?buttons=y so that mirador works
          if (fullurl.include?('https://ids') && !fullurl.include?('?buttons=y'))
            fullurl = fullurl + '?buttons=y'
            @item_solr['full_image_url_ssm'] =  fullurl
          end         
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
        #Append /native.jpg to end if it doesn't exist
        if (!uri.include?('native.jpg'))
          uri = uri + "/full/180,/0/native.jpg"
        elsif (uri.include?("full/,150/"))
          uri = uri.sub(/full\/,150\//,"full/180,/")
        end    
        uri
      end

    end
  end
end
