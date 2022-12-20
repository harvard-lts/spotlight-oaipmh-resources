require 'net/http'
require 'uri'

module Spotlight
  class SolrHarvester < Harvester
    ROW_COUNT = 1000
    DEFAULT_SORT_FIELD = '_id'

    alias_attribute :mapping_file, :solr_mapping_file

    def self.mapping_files
      super('solrmapping')
    end

    def harvest_items(job_tracker: nil, job_progress: nil)
      self.total_errors = 0
      @sidecar_ids = []
      solr_converter.parse_mapping_file(solr_converter.mapping_file) 
      harvests = solr_harvests
      @cursor = harvests['nextCursorMark']

      update_progress_total(job_progress)
      last_page_evaluated = harvests['response']['docs'].blank?
      while (!last_page_evaluated)
        harvests['response']['docs'].each do |record|
          harvest_item(record, job_tracker, job_progress)
        end

        unless last_page_evaluated 
          harvests = solr_harvests(@cursor)
          @cursor = harvests['nextCursorMark']
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

    def solr_harvests(cursor = nil)
      cursor = cursor.presence || '*'
      sort_field = sort_field_for_set(set)
            
      if !filter.empty?                                        
        filter_value = "#{filter}"
      else                                           
        filter_value = '*:*'                             
      end  

      solr_connection.get(        
        'select',                          
        params: {                             
          q: filter_value,
          cursorMark: cursor,
          sort: "#{sort_field} asc",
          rows: ROW_COUNT,
          wt: 'json'
        }
      )
    end

    # This is meant to be a temporary solution to compensate for inconsistent data
    # structures between the Solr sets.
    #
    # Our Solr harvest endpoint (https://fts.lib.harvard.edu/solr/) requires queries
    # to use a "cursor" (as opposed to pagination, for example). Solr queries that
    # use a cursor require a field that has a unique value to sort on.
    #
    # The Solr sets currently (2022-10-28) do not all use a consistent field that
    # meets this requirement. Some store the unique value in a field called "_id",
    # some store the field in a field called "id".
    #
    # Due to this inconsistency in the structure of the Solr data, a file has been
    # added to explicitly declare what the unique field is for each Solr set.
    #
    # This method (and related logic) can be removed once the Solr data is changed
    # to use a consistent unique identifying field.
    def sort_field_for_set(set)
      file = File.join(
        Spotlight::Oaipmh::Resources::Engine.root,
        'harvard_yaml_mapping_files',
        'solr',
        'unique_key_mappings',
        'unique_keys_by_set.yml'
      )
      return DEFAULT_SORT_FIELD unless File.exists?(file)

      YAML.load_file(file).dig(set, 'unique_key').presence || DEFAULT_SORT_FIELD
    end

    def complete_list_size
      @complete_list_size ||= solr_harvests['response']['numFound'] || 0
    end

    def solr_connection
      # Add trailing "/" if it's missing from base_url
      valid_base_url = base_url.match?(/\/$/) ? base_url : base_url + '/'
      # If we want to add a solr query, check that field, if not we don't need it
      solr_url = valid_base_url + set

      @solr_connection ||= RSolr.connect(url: solr_url)
    end

    def solr_converter
      @solr_converter ||= Spotlight::Resources::SolrConverter.new(set, exhibit.slug, get_mapping_file)
    end
  end
end
