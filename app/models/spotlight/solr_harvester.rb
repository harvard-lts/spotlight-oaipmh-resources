require 'net/http'
require 'uri'

module Spotlight
  class SolrHarvester < Harvester
    ROW_COUNT = 50

    alias_attribute :mapping_file, :solr_mapping_file

    def self.mapping_files
      super('solrmapping')
    end

    def get_harvests
      @solr_connection = RSolr.connect :url => @url  
      response = @solr_connection.paginate 0, ROW_COUNT, 'select', :params => {:q => '*:*', :wt => 'json'}
    end

    def paginate (page)
      if (@solr_connection.nil?)
        @solr_connection = RSolr.connect :url => @url  
      end
      response = @solr_connection.paginate page, ROW_COUNT, 'select', :params => {:q => '*:*', :wt => 'json'}
    end

    def harvest_solr_items
      max_batch_count = Spotlight::Oaipmh::Resources::Engine.config.solr_harvest_batch_max
      solr_converter = SolrConverter.new(set, exhibit.slug, get_mapping_file)
      solr_converter.parse_mapping_file(solr_converter.mapping_file) 
      last_page_evaluated = harvests['response']['docs'].blank?
      unique_id_field = nil 
      if (!solr_converter.get_unique_id_field.nil?)
        unique_id_field = solr_converter.get_unique_id_field
      end
      count = 0
      totalrecords = 0

      #If the resumption token was stored, begin there.
      if !cursor.blank?
        page = cursor
        harvests = paginate(page)
      else
        page = 1
        harvests = harvests
      end

      if !count.blank?
        totalrecords = count
      end

      while (!last_page_evaluated)
        harvests['response']['docs'].each do |record|
          parsed_solr_item = SolrHarvestingParser.new(exhibit, solr_converter)

          parsed_solr_item.metadata = record
          parsed_solr_item.parse_record(unique_id_field)
          parsed_solr_item.to_solr
          begin
            # Create clean resource for editing
            resource = Spotlight::Resources::SolrUpload.find_or_initialize_by(exhibit: exhibit, external_id: parsed_solr_item.id.upcase)
            resource.data = parsed_solr_item.sidecar_data
            resource.save_and_index

            count = count + 1
            totalrecords = totalrecords + 1
            curtime = Time.zone.now
            get_job_entry.update(job_item_count: totalrecords, end_time: curtime)
          rescue Exception => e
            Delayed::Worker.logger.add(Logger::ERROR, parsed_solr_item.id + ' did not index successfully')
            Delayed::Worker.logger.add(Logger::ERROR, e.message)
            Delayed::Worker.logger.add(Logger::ERROR, e.backtrace)
          end
        end #End of each loop
        page = page + 1
        #Stop harvesting if the batch has reached the maximum allowed value
        if (!last_page_evaluated) 
          if (max_batch_count != -1 && count >= max_batch_count)
            schedule_next_batch(page, totalrecords)
            break
          else
            harvests = paginate(page)
          end
        end

        #Terminate the loop if it is empty        
        if (harvests['response']['docs'].blank?)
          last_page_evaluated = true
        end
      end #End of while loop
      if (last_page_evaluated)
        get_job_entry.succeeded!
      end
    rescue
      get_job_entry.failed!
      raise
    end

    def get_unique_id_field_name(mapping_file)
      mapping_config = YAML.load_file(mapping_file)
      mapping_config.each do |field|
        if (!field.key?("spotlight-field") || field['spotlight-field'].blank?)
          raise InvalidMappingFile, "spotlight-field is required for each entry"
        end
      end
    end

    def schedule_next_batch(cursor, count)
      Spotlight::Resources::PerformHarvestsJob.perform_later(type, base_url, set, mapping_file, exhibit, user, job_entry, cursor, count)
    end
  end
end
