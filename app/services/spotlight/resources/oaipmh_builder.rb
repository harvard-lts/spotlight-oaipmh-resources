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
        
        oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
        
        harvests = resource.oaipmh_harvests
        resumption_token = harvests.resumption_token
        until (resumption_token.nil?)
          harvests.each do |record|
            item = OaipmhModsItem.new(exhibit, oai_mods_converter, cna_config)
            
            item.metadata = record.metadata
            parsed_hash = item.parse_mods_record()
            
            item_solr = item.to_solr
            
            ###CNA Specific - Language and origin
            lang_field_name = oai_mods_converter.get_spotligh_field_name("language_ssim")
            origin_field_name = oai_mods_converter.get_spotligh_field_name("origin_ssim")
            language = perform_lookups(item_solr[lang_field_name], "lang")
            origin = perform_lookups(item_solr[origin_field_name], "orig")
            item_solr[lang_field_name] = language
            item_solr[origin_field_name] = origin
            
            ##CNA Specific - Subjects
            subject_field_name = oai_mods_converter.get_spotligh_field_name("subjects_ssim")
            if (item_solr.key?(subject_field_name) && !item_solr[subject_field_name].nil?)
              #Split on |
              subjects = item_solr[subject_field_name].split('|')
              item_solr[subject_field_name] = subjects
            end
            
            
            record_type_field_name = oai_mods_converter.get_spotligh_field_name("record-type_ssim")
            record_type_collection = oai_mods_converter.get_spotligh_field_name("record-type_collection_ssim")
            record_type_item = oai_mods_converter.get_spotligh_field_name("record-type_item_ssim")
               
            ##CNA Specific - catalog
            catalog_url_field_name = oai_mods_converter.get_spotligh_field_name("catalog-url_tesim")
            catalog_url_item = oai_mods_converter.get_spotligh_field_name("catalog-url_item_tesim")
              
            #THIS IS SPECIFIC TO CNA   
                               
            #If the collection field is populated then it is a collection, otherwise it is an item.
            if (item_solr.key?(record_type_collection) && !item_solr[record_type_collection].blank?)
              item_solr[record_type_field_name] = "collection"
              item_solr.delete(record_type_collection)
              
              ##CNA Specific - catalog
              if (item_solr.key?(catalog_url_item) && !item_solr[catalog_url_item].nil?)
                item_solr[catalog_url_field_name] = cna_config['ALEPH_URL'] + item_solr[catalog_url_item] + "/catalog"
                item_solr.delete(catalog_url_item)
              end
            else
              item_solr[record_type_field_name] = "item"
              item_solr.delete(record_type_item)
              item_solr.delete(catalog_url_item)
              
              ##CNA Specific
              catalog_url = item.get_catalog_url
              if (!catalog_url.blank?)
                item_solr[catalog_url_field_name] = catalog_url
                #Extract the ALEPH ID from the URL
                catalog_url_array = catalog_url.split('/').last(2)
                collection_id_tesim = oai_mods_converter.get_spotligh_field_name("collection_id_tesim")
                item_solr[collection_id_tesim] = catalog_url_array[0]
              end
              
              finding_aid_url = item.get_finding_aid
              if (!finding_aid_url.blank?)
                finding_aid_url_field_name = oai_mods_converter.get_spotligh_field_name("finding-aid_tesim")
                item_solr[finding_aid_url_field_name] = finding_aid_url
              end 
            end
            
            if (item_solr.key?('thumbnail_url_ssm') && !item_solr['thumbnail_url_ssm'].blank? && !item_solr['thumbnail_url_ssm'].eql?('null'))
              
              thumburl = item_solr['thumbnail_url_ssm']
                            
              thumburl = thumburl.split('?')[0]
              
              thumb = nil
              fullurl = nil
              square = nil
              fullimagefile = nil
              
              #If the images haven't been uploaded, then upload them.
              #This is restricted to one time because it is time-consuming
              if (!Dir.exist?(Rails.root.join("public",item.itemurl.store_dir)))
                item.remote_itemurl_url = thumburl
                item.store_itemurl!
                
                if (!item.itemurl.nil? && !item.itemurl.file.nil? && !item.itemurl.file.file.nil?)
                  fullimagefile = item.itemurl.file.file
                  fullurl = item.itemurl.file.file
                end
                
                if (!item.itemurl.nil? && !item.itemurl.thumb.nil?)
                  thumb = item.itemurl.thumb.file.file
                end
                if (!item.itemurl.nil? && !item.itemurl.square.nil?)
                  square = item.itemurl.square.file.file
                end
  
              else
                files = Dir.entries(Rails.root.join("public",item.itemurl.store_dir))
                files.delete(".")
                files.delete("..")
                
                files.each do |f|
                  if (f.start_with?('thumb'))
                    thumb = File.join("/",item.itemurl.store_dir,f)                   
                  elsif (f.start_with?('square'))
                    square = File.join("/",item.itemurl.store_dir,f)
                  else
                    fullurl = File.join("/",item.itemurl.store_dir,f)
                    fullimagefile = File.open(Rails.root.join("public",item.itemurl.store_dir,f))
                  end
                end
              end  
              item_solr = add_image_info(item_solr, fullurl, thumb, square)
              item_solr = add_image_dimensions(item_solr, fullimagefile)
            end
                
            yield base_doc.merge(item_solr) if item_solr.present?
       
          end
          harvests = resource.resumption_oaipmh_harvests(resumption_token)
          resumption_token = harvests.resumption_token
        end
      end
   
      #Adds the solr image info
      def add_image_info(solr_hash, fullurl, thumb, square)
          if (!thumb.nil?)
            solr_hash[:thumbnail_url_ssm] = thumb
              
          end
        
          if (!fullurl.nil?)
            if (!square.nil?)
              square = File.dirname(fullurl) + '/square_' + File.basename(fullurl)
            end
            solr_hash[:thumbnail_square_url_ssm] = square
            solr_hash[:full_image_url_ssm] = fullurl
          end
                      
        solr_hash                
      end
      
      #Adds the solr image dimensions
      def add_image_dimensions(solr_hash, file)
        if (!file.nil?)
          dimensions = ::MiniMagick::Image.open(file)[:dimensions]
          solr_hash[:spotlight_full_image_width_ssm] = dimensions.first
          solr_hash[:spotlight_full_image_height_ssm] = dimensions.last
          solr_hash
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

    end
  end
end
