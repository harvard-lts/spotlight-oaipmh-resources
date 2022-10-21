require 'net/http'
require 'uri'

module Spotlight
  class SolrHarvester < Harvester
    ROW_COUNT = 50

    alias_attribute :mapping_file, :solr_mapping_file

    def self.mapping_files
      super('solrmapping')
    end

    def harvest_items(job_tracker: nil, job_progress: nil)
      self.total_errors = 0
      @sidecar_ids = []
      solr_converter.parse_mapping_file(solr_converter.mapping_file) 
      page = 1
      harvests = solr_harvests(page)

      update_progress_total(job_progress)
      last_page_evaluated = harvests['response']['docs'].blank?
      while (!last_page_evaluated)
        harvests['response']['docs'].each do |record|
          harvest_item(record, job_tracker, job_progress)
        end

        page += 1
        unless last_page_evaluated 
          harvests = solr_harvests(page)
          update_progress_total(job_progress) # set size can change mid-harvest
        end

        # Terminate the loop if it is empty
        last_page_evaluated = true if harvests['response']['docs'].blank?

        # Log an update every 100 records
        if (job_progress.progress % 100).zero?
          job_tracker.append_log_entry(type: :info, exhibit: exhibit, message: "#{job_progress.progress} of #{job_progress.total} (#{self.total_errors} errors)")
        end
      end
      @sidecar_ids
    end

    def harvest_item(record, job_tracker, job_progress)
      parsed_solr_item = Spotlight::Resources::SolrHarvestingParser.new(exhibit, solr_converter)

      parsed_solr_item.metadata = record
      parsed_solr_item.parse_record(solr_converter.get_unique_id_field)
      # At this point, we know the candidate for the sidecar's document_id.  This will be used in
      # the Spotlight::Resources::LoadUrnsJob
      @sidecar_ids << parsed_solr_item.id if Spotlight::Oaipmh::Resources.use_solr_document_urns
      parsed_solr_item.to_solr

      # Create clean resource for editing
      resource = Spotlight::Resources::SolrUpload.find_or_initialize_by(exhibit: exhibit, external_id: parsed_solr_item.id.upcase)
      resource.data = parsed_solr_item.sidecar_data
      # The resource's sidecar is set up correctly the first time; nothing special is required
      if resource.solr_document_sidecars.blank?
        resource.save_and_index
      else
        # As of Spotlight v3.3.0, if a resource already has a sidecar, the sidecar (and thus the data in Solr)
        # will not update unless done explicitly. The sidecar's #data is organized differently than the
        # resource's #data, so we can't just copy it over from the resource directly.
        resource.save!
        sidecar = resource.solr_document_sidecars.first
        sidecar.data = parsed_solr_item.reorganize_sidecar_data
        sidecar.save!
        # Get the updated sidecar into our local variable to ensure proper indexing
        resource.reload.reindex_later
      end

      job_progress&.increment
    rescue Exception => e
      handle_item_harvest_error(e, parsed_solr_item, job_tracker)
    end

    def solr_harvests(page = nil)
      page = page.presence || 1
      solr_connection.paginate(page, ROW_COUNT, 'select', params: { q: '*:*', wt: 'json' })
    end

    def complete_list_size
      @complete_list_size ||= solr_harvests['response']['numFound'] || 0
    end

    def solr_connection
      solr_url = base_url + set
      @solr_connection ||= RSolr.connect(url: solr_url)
    end

    def solr_converter
      @solr_converter ||= Spotlight::Resources::SolrConverter.new(set, exhibit.slug, get_mapping_file)
    end
  end
end
