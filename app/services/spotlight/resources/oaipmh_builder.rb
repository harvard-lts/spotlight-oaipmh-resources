module Spotlight
  module Resources
    # transforms a OaipmhHarvester into solr documents
    class OaipmhBuilder < Spotlight::SolrDocumentBuilder
      #include OAI::XPath
      def to_solr
        #@resource.to_solr
#        throw 'error'
        return to_enum(:to_solr) { 0 } unless block_given?

        base_doc = super
        
        oai_mods_converter = OaipmhModsConverter.new(resource.set, resource.metadata)
        
        i = 0
        resource.oaipmh_harvests.each do |record|
          if (i < 5)
                  
                item = OaipmhModsItem.new(exhibit, oai_mods_converter)
                item.metadata = record.metadata
                item.parse_mods_record
                #item.parse_mods_record(modsrecord)
                
                item_solr = item.to_solr
                yield base_doc.merge(item_solr) if item_solr.present?
                i = i + 1
          end
        end
      end
    end
  end
end
