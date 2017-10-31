module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class OaipmhBuilder < Spotlight::SolrDocumentBuilder
      
      def to_solr
        return to_enum(:to_solr) { 0 } unless block_given?

        base_doc = super
                
        mapping_file = nil
        if (!resource.data[:mapping_file].eql?("Default Mapping File") && !resource.data[:mapping_file].eql?("New Mapping File"))
          mapping_file = resource.data[:mapping_file]
        end
        
        @oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
        
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
              
              parse_subjects()
              parse_types()
              
              repository_field_name = @oai_mods_converter.get_spotlight_field_name("repository_ssim")
              
              process_image_data()
              
              uniquify_repos(repository_field_name)
              
              #Add the sidecar info for editing
              sidecar ||= resource.document_model.new(id: @item.id).sidecar(resource.exhibit)   
              sidecar.update(data: @item_sidecar)
              yield base_doc.merge(@item_solr) if @item_solr.present?
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
  
  
      def process_image_data()
        if (@item_solr.key?('thumbnail_url_ssm') && !@item_solr['thumbnail_url_ssm'].blank? && !@item_solr['thumbnail_url_ssm'].eql?('null'))           
          thumburl = @item_solr['thumbnail_url_ssm']
          thumburl = thumburl.split('?')[0]
            
          thumb = nil
          fullurl = nil
          square = nil
          fullimagefile = nil
          
          #If the images haven't been uploaded, then upload them.
          #This is restricted to one time because it is time-consuming
          dir = Rails.root.join("public",@item.itemurl.store_dir)
          if (!Dir.exist?(dir))
            @item.remote_itemurl_url = thumburl
            @item.store_itemurl!
          
            if (!@item.itemurl.nil? && !@item.itemurl.file.nil? && !@item.itemurl.file.file.nil?)
              filename = @item.itemurl.file.file
              #strip off everything before the /uploads
              filenamearray = filename.split("/uploads")
              if (filenamearray.length == 2)
                filename = "/uploads" + filenamearray[1]
              end
              fullimagefile = @item.itemurl.file.file
              fullurl = filename
            end
            
            if (!@item.itemurl.nil? && !@item.itemurl.thumb.nil? && !@item.itemurl.thumb.file.nil?)
              filename = @item.itemurl.thumb.file.file
              #strip off everything before the /uploads
              filenamearray = filename.split("/uploads")
              if (filenamearray.length == 2)
                filename = "/uploads" + filenamearray[1]
              end
                                
              thumb = filename
            end
            
            if (!@item.itemurl.nil? && !@item.itemurl.square.nil? && !@item.itemurl.square.file.nil?)
              filename = @item.itemurl.square.file.file
              # strip off everything before the /uploads
              filenamearray = filename.split("/uploads")
              if (filenamearray.length == 2)
                filename = "/uploads" + filenamearray[1]
              end
                                
              square = filename
            end 
          else
            files = Dir.entries(Rails.root.join("public",@item.itemurl.store_dir))
            files.delete(".")
            files.delete("..")
            
            files.each do |f|
              if (f.start_with?('thumb'))
                thumb = File.join("/",@item.itemurl.store_dir,f)                   
              elsif (f.start_with?('square'))
                square = File.join("/",@item.itemurl.store_dir,f)
              else
                fullurl = File.join("/",@item.itemurl.store_dir,f)
                fullimagefile = File.open(Rails.root.join("public",@item.itemurl.store_dir,f))
              end
            end
          end      
          add_image_info(fullurl, thumb, square)
          add_image_dimensions(fullimagefile)
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

    end
  end
end
