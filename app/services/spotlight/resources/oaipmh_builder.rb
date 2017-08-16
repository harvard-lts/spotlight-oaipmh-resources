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
        
        cna_config = YAML.load_file(Spotlight::Oaipmh::Resources::Engine.root + 'config/cna_config.yml')[Rails.env]
        
        @oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
        
        harvests = resource.oaipmh_harvests
        resumption_token = harvests.resumption_token
        until (resumption_token.nil?)
          harvests.each do |record|
            @item = OaipmhModsItem.new(exhibit, @oai_mods_converter, cna_config)
            
            @item.metadata = record.metadata
            @item.parse_mods_record()
            begin
              @item_solr = @item.to_solr
              @item_sidecar = @item.sidecar_data
              
              #CNA Specific
              lookup_languages_and_origins()     
              parse_subjects()
              
              record_type_field_name = @oai_mods_converter.get_spotlight_field_name("record-type_ssim")
                 
              ##CNA Specific - catalog
              catalog_url_field_name = @oai_mods_converter.get_spotlight_field_name("catalog-url_tesim")
              catalog_url_item = @oai_mods_converter.get_spotlight_field_name("catalog-url_item_tesim")
         
              #THIS IS SPECIFIC TO CNA   
              repository_field_name = @oai_mods_converter.get_spotlight_field_name("repository_ssim")
                                  
              #If the collection field is populated then it is a collection, otherwise it is an item.
              if (!@item_solr[record_type_field_name].nil? && !@item_solr[record_type_field_name].eql?("item"))
                set_collection_specific_data(record_type_field_name)
              else
                set_item_specific_data(record_type_field_name)
                process_image_data()
              end
  
              uniquify_repos(repository_field_name)
              
              #Add the sidecar info for editing
              sidecar ||= resource.document_model.new(id: @item.id).sidecar(resource.exhibit)   
              sidecar.update(data: @item_sidecar)
              yield base_doc.merge(@item_solr) if @item_solr.present?
            rescue
              Delayed::Worker.logger.add(Logger::ERROR, @item.id + ' did not index successfully')
            end
          end
          harvests = resource.resumption_oaipmh_harvests(resumption_token)
          resumption_token = harvests.resumption_token
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
      
      def perform_lookups(input, data_type)
        
        import_arr = []
        if (!input.to_s.blank?)
          input_codes = input.split('|')
          
          input_codes.each do |code|
            code = code.strip
            if (!code.blank?)
              item = nil
              if data_type == "lang"
                item = Language.find_by(code: code)
              else
                item = Origin.find_by(code: code)
              end

              if item.nil?
                import_arr.push(code)
              else
                import_arr.push(item.name)
              end
            end
          end
        end
                
        import_arr
      end
 
private   
 
      def lookup_languages_and_origins()
        ###CNA Specific - Language and origin
        lang_field_name = @oai_mods_converter.get_spotlight_field_name("language_ssim")
        origin_field_name = @oai_mods_converter.get_spotlight_field_name("origin_ssim")
        language = perform_lookups(@item_solr[lang_field_name], "lang")
        origin = perform_lookups(@item_solr[origin_field_name], "orig")
        @item_solr[lang_field_name] = language
        @item_solr[origin_field_name] = origin
        @item_sidecar["language_ssim"] = language
        @item_sidecar["origin_ssim"] = origin
      end
      
      def parse_subjects()
        ##CNA Specific - Subjects
        subject_field_name = @oai_mods_converter.get_spotlight_field_name("subjects_ssim")
        if (@item_solr.key?(subject_field_name) && !@item_solr[subject_field_name].nil?)
          #Split on |
          subjects = @item_solr[subject_field_name].split('|')
          @item_solr[subject_field_name] = subjects
          @item_sidecar["subjects_ssim"] = subjects
        end
      end
      
      def set_collection_specific_data()
        catalog_url_field_name = @oai_mods_converter.get_spotlight_field_name("catalog-url_tesim")
        catalog_url_item = @oai_mods_converter.get_spotlight_field_name("catalog-url_item_tesim")
               
        @item_solr[record_type_field_name] = "collection"
        @item_sidecar["record-type_ssim"] = "collection"
          
        ##CNA Specific - catalog
        if (@item_solr.key?(catalog_url_item) && !@item_solr[catalog_url_item].nil?)
          @item_solr[catalog_url_field_name] = cna_config['ALEPH_URL'] + @item_solr[catalog_url_item] + "/catalog"
          collection_id_tesim = @oai_mods_converter.get_spotlight_field_name("collection_id_tesim")
          @item_solr[collection_id_tesim] = @item_solr[catalog_url_item]
          @item_sidecar["collection_id_tesim"] = @item_solr[catalog_url_item]
          @item_solr.delete(catalog_url_item)  
        end
      end
      
      def set_item_specific_data()
        catalog_url_field_name = @oai_mods_converter.get_spotlight_field_name("catalog-url_tesim")
        catalog_url_item = @oai_mods_converter.get_spotlight_field_name("catalog-url_item_tesim")
                
        @item_solr[record_type_field_name] = "item"
        @item_sidecar["record-type_ssim"] = "item"
        
        ##CNA Specific
        catalog_url = @item.get_catalog_url
        if (!catalog_url.blank?)
          @item_solr[catalog_url_field_name] = catalog_url
          #Extract the ALEPH ID from the URL
          catalog_url_array = catalog_url.split('/').last(2)
          collection_id_tesim = @oai_mods_converter.get_spotlight_field_name("collection_id_tesim")
          @item_solr[collection_id_tesim] = catalog_url_array[0]
          @item_sidecar["collection_id_tesim"] = catalog_url_array[0]
        end

        finding_aid_url = @item.get_finding_aid
        if (!finding_aid_url.blank?)
          finding_aid_url_field_name = @oai_mods_converter.get_spotlight_field_name("finding-aid_tesim")
          @item_solr[finding_aid_url_field_name] = finding_aid_url
          @item_sidecar["finding-aid_tesim"] = finding_aid_url
        end 
        
        #If the creator doesn't exist from the mapping, we have to extract it from the related items (b/c it is an EAD component)
        creator_field_name = @oai_mods_converter.get_spotlight_field_name("creator_tesim")
        if (!@item_solr.key?(creator_field_name) || @item_solr[creator_field_name].blank?)
          creator = @item.get_creator
          if (!creator.blank?)
            @item_solr[creator_field_name] = creator
            @item_sidecar["creator_tesim"] = creator
          end
        end
        
        #If the repository doesn't exist from the mapping, we have to extract it from the related items (b/c it is an EAD component)
        if (!@item_solr.key?(repository_field_name) || @item_solr[repository_field_name].blank?)
          repo = @item.get_repository
          if (!repo.blank?)
            @item_solr[repository_field_name] = repo
            @item_sidecar["repository_ssim"] = repo
          end
        end
      
        #If the collection title doesn't exist from the mapping, we have to extract it from the related items (b/c it is an EAD component)
        coll_title_field_name = @oai_mods_converter.get_spotlight_field_name("collection-title_ssim")
        if (!@item_solr.key?(coll_title_field_name) || @item_solr[coll_title_field_name].blank?)
          colltitle = @item.get_collection_title
          if (!colltitle.blank?)
            @item_solr[coll_title_field_name] = colltitle
            @item_sidecar["collection-title_ssim"] = colltitle
          end
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
        if (@item_solr.key?(repository_field_name))
          repoarray = @item_solr[repository_field_name].split("|")
          if (@item.id.eql?('000603974'))
            Delayed::Worker.logger.add(Logger::ERROR, 'REPO FOR 000603974>>>>>>')
            Delayed::Worker.logger.add(Logger::ERROR, @item_solr[repository_field_name])
          end
          repoarray = repoarray.uniq
          repo = repoarray.join("|")
          if (@item.id.eql?('000603974'))
            Delayed::Worker.logger.add(Logger::ERROR, 'UNIQUE FOR 000603974>>>>>>')
            Delayed::Worker.logger.add(Logger::ERROR, repo)
          end
          @item_solr[repository_field_name] = repo
          @item_sidecar["repository_ssim"] = repo
        end
      end

    end
  end
end
