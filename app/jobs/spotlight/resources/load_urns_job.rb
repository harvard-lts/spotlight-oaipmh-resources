include Spotlight::Resources::Exceptions
# encoding: utf-8
module Spotlight::Resources
  ##
  # Process a CSV upload into new Spotlight::Resource::Upload objects
  class LoadUrnsJob < ActiveJob::Base
    queue_as :default

    def perform(sidecar_ids:, user: nil)
      sidecar_ids
      total_errors = 0

      sidecar_ids.each do |sidecar_id|
        sidecar = Spotlight::SolrDocumentSidecar.where(document_id: sidecar_id).first
        (total_errors += 1 && next) unless sidecar

        sidecar.urn = sidecar.data['configured_fields']['urn_ssi']
        sidecar.save!
      end
      total_errors
    end
  end
end
