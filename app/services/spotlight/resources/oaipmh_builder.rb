module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class OaipmhBuilder < Spotlight::SolrDocumentBuilder
      #mount_uploader :url, Spotlight::ItemUploader
      
      def to_solr
        return to_enum(:to_solr) { 0 } unless block_given?

        base_doc = super
        
        mapping_file = nil
        if (!resource.data[:mapping_file].eql?("Default Mapping File") && !resource.data[:mapping_file].eql?("New Mapping File"))
          mapping_file = resource.data[:mapping_file]
        end
        
        oai_mods_converter = OaipmhModsConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
        
        i = 0
        resource.oaipmh_harvests.each do |record|
          if (i < 5)
                puts i  
                item = OaipmhModsItem.new(exhibit, oai_mods_converter)
               
                item.metadata = record.metadata
                puts record.metadata.to_s
                parsed_hash = item.parse_mods_record()
                
                item_solr = item.to_solr
                
                tempurl = "http://ids.lib.harvard.edu/ids/view/422688862"
                
                thumb = nil
                fullurl = nil
                square = nil
                fullimagefile = nil
                
                #If the images haven't been uploaded, then upload them.
                #This is restricted to one time because it is time-consuming
                if (!Dir.exist?(Rails.root.join("public",item.itemurl.store_dir)))
                  item.remote_itemurl_url = tempurl
                  item.store_itemurl!
                  
                  if (!item.itemurl.nil? && !item.itemurl.file.nil? && !item.itemurl.file.file.nil?)
                    fullimagefile = item.itemurl.file.file
                  end
                  
                  if (!item.itemurl.nil?)
                    thumb = item.itemurl.thumb
                    fullurl = item.itemurl
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

                i = i + 1
                yield base_doc.merge(item_solr) if item_solr.present?
                
          end
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

    end
  end
end
