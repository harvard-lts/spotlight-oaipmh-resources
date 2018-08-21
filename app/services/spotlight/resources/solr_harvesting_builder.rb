module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class SolrHarvestingBuilder < Spotlight::SolrDocumentBuilder
      
      def to_solr
        begin
        return to_enum(:to_solr) { 0 } unless block_given?

        base_doc = super
           
        mapping_file = nil
        if (!resource.data[:solr_mapping_file].eql?("Default Mapping File") && !resource.data[:solr_mapping_file].eql?("New Mapping File"))
          mapping_file = resource.data[:mapping_file]
        end
        
        @solr_converter = SolrConverter.new(resource.data[:set], resource.exhibit.slug, mapping_file)
                          
        count = 0
        page = 1
        harvests = resource.harvests
        last_page_evaluated = false
        until (last_page_evaluated || harvests['response']['docs'].blank?)
          #once we reach the last page

          harvests['response']['docs'].each do |record|
            @item = SolrHarvestingItem.new(exhibit, @solr_converter)
            
            @item.metadata = record
            @item.parse_record()
            begin
              @item_solr = @item.to_solr
              @item_sidecar = @item.sidecar_data
              
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
          end #End of each loop

          page = page + 1
          harvests = resource.paginate(page)  
          #Terminate the loop if it is empty        
          if (harvests['response']['docs'].blank?)
            last_page_evaluated = true
          end
        end #End of until loop
        rescue
          resource.get_job_entry.failed!
          raise
        end
        resource.get_job_entry.succeeded!
      end

    end
  end
end
