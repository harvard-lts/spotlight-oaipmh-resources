include Spotlight::Resources::Exceptions
module Spotlight::Resources
  class SolrHarvestingParser
    attr_reader :titles, :id
    attr_accessor :metadata, :sidecar_data
    def initialize(exhibit, converter)
      @solr_hash = {}
      @exhibit = exhibit
      @converter = converter
    end
    
    def to_solr
      add_document_id
      solr_hash
    end
    
    def parse_record(unique_id_field)
      if (!metadata[unique_id_field].blank?)
        if (metadata[unique_id_field].kind_of?(Array))
          @id = metadata[unique_id_field][0]
        else
          @id = metadata[unique_id_field] 
        end
        
        #Strip out all of the decimals
        @id = @id.gsub('.', '')
        @id = @exhibit.id.to_s + "-" + @id.to_s
      end
      
      @solr_hash = @converter.convert(metadata)
      @sidecar_data = organize_sidecar_data(@converter.sidecar_hash)
   end
  
   # private
    
    attr_reader :solr_hash, :exhibit

    
    def add_document_id
      if (!@id.blank?)
        solr_hash[:id] = @id.to_s
      else
        #Generate a random number if no unique id is supplied.
        solr_hash[:id] = rand.to_s[2..11] 
      end
    end

    # Spotlight v3.3.0
    # Spotlight expects "exhibit-specific fields" (a.k.a. Exhibit#custom_fields) to not have
    # a Solr suffix (e.g. _tesim, _ssim, etc.). This method assumes all non-configured fields
    # are custom and thus removes their Solr suffix when adding them to the @item_sidecar hash.
    # Configured fields are added as-is (Solr suffix included).
    def organize_sidecar_data(hash)
      organized_sidecar_data = {}

      hash.each do |field_name, value|
        if configured_field_names.include?(field_name)
          organized_sidecar_data[field_name] = value
        else
          custom_field_slug = field_name.sub(/_[^_]+$/, '')
          organized_sidecar_data[custom_field_slug] = value
        end
      end

      organized_sidecar_data
    end

    # Spotlight v3.3.0
    # Used to update an existing sidecar's data when harvesting (see
    # Spotlight::SolrHarvester#harvest_item). Default "configured" fields are expected
    # to be nested in a "configured_fields" sub-hash. This method assumes non-configured
    # fields are "exhibit-specific fields" (a.k.a. Exhibit#custom_fields) and puts them
    # in the "top level" of the hash (where Spotlight expects them to be).
    #
    # Example:
    # {
    #   'configured_fields' => {
    #     'full_title_tesim' => 'My Title'
    #   },
    #   'custom-field' => 'Hello world'
    # }
    #
    # @return [Hash] Sidecar data organized in the format that Spotlight expects
    def reorganize_sidecar_data
      reorganized_sidecar_data = { 'configured_fields' => {} }
      custom_field_slugs = exhibit.custom_fields.map(&:slug)

      @sidecar_data.map do |field_name, value|
        reorganized_sidecar_data['configured_fields'][field_name] = value if configured_field_names.include?(field_name)
        next unless custom_field_slugs.include?(field_name)

        reorganized_sidecar_data[field_name] = value
      end

      reorganized_sidecar_data
    end

    # @return [Array<String>] List of default fields names as configured in config/initializers/spotlight_initializer.rb
    def configured_field_names
      # Add full_title_tesim to the list since it's a default Spotlight field
      @configured_field_names ||= ['full_title_tesim'] + exhibit.uploaded_resource_fields.map(&:field_name).map(&:to_s)
    end
  end
end
