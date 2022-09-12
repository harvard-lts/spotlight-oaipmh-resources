include Spotlight::Resources::Exceptions
# encoding: utf-8
module Spotlight::Resources
  ##
  # Process a CSV upload into new Spotlight::Resource::Upload objects
  class LoadUrnsJob < ActiveJob::Base
    queue_as :default

    # @return [Integer] total number of URN errors
    def perform(job_tracker:, sidecar_ids:, user: nil)
      total_errors = 0

      sidecar_ids.each do |sidecar_id|
        sidecar = Spotlight::SolrDocumentSidecar.where(document_id: sidecar_id).first
        unless sidecar
          message = "Missing Spotlight::SolrDocumentSidecar for document_id=#{sidecar_id}"
          job_tracker&.append_log_entry(type: :error, exhibit: exhibit, message: message)
          total_errors += 1
          next
        end

        sidecar.urn = sidecar.data['configured_fields']['urn_ssi']

        begin
          sidecar.save!
        rescue ActiveRecord::RecordInvalid => e
          message = "Invalid data for Spotlight::SolrDocumentSidecar for document_id=#{sidecar_id}"
          job_tracker&.append_log_entry(type: :error, exhibit: exhibit, message: message)
          job_tracker&.append_log_entry(type: :error, exhibit: exhibit, message: e.message)
          total_errors += 1
        end
      end
      missing_sidecar_ids
    end
  end
end
