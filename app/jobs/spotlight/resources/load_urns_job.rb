include Spotlight::Resources::Exceptions
# encoding: utf-8
module Spotlight::Resources
  ##
  # Process a CSV upload into new Spotlight::Resource::Upload objects
  class LoadUrnsJob < ActiveJob::Base
    queue_as :default

    # @return [Array<Object>] the document ids that don't have corresponding sidecars.
    def perform(sidecar_ids:, user: nil)
      missing_sidecar_ids = []

      sidecar_ids.each do |sidecar_id|
        sidecar = Spotlight::SolrDocumentSidecar.where(document_id: sidecar_id).first
        unless sidecar
          missing_sidecar_ids << sidecar_id
          next
        end

        sidecar.urn = sidecar.data['configured_fields']['urn_ssi']
        sidecar.save!
      end
      missing_sidecar_ids
    end
  end
end
