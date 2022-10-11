include Spotlight::Resources::Exceptions
# encoding: utf-8
module Spotlight::Resources
  ##
  # Process a CSV upload into new Spotlight::Resource::Upload objects
  class LoadUrnsJob < ActiveJob::Base
    queue_as :default

    # @return [Integer] total number of URN errors
    def perform(job_tracker:, sidecar_ids:, exhibit:, user: nil)
      total_warnings = 0

      sidecar_ids.map(&:upcase).each do |sidecar_id|
        sidecar = Spotlight::SolrDocumentSidecar.find_by(document_id: sidecar_id)
        unless sidecar
          # Note: type warning will bubble up to .table-warning in the CSS, which per Bootstrap
          #       documentation will be highlighted in yellow.
          #
          # https://getbootstrap.com/docs/4.0/content/tables/
          message = "Missing Spotlight::SolrDocumentSidecar for document_id=#{sidecar_id}"
          job_tracker.append_log_entry(type: :warning, exhibit: exhibit, message: message)
          total_warnings += 1
          next
        end

        sidecar.urn = sidecar.data['configured_fields']['urn_ssi']

        begin
          sidecar.save!
        rescue ActiveRecord::RecordInvalid => e
          # Note: type warning will bubble up to .table-warning in the CSS, which per Bootstrap
          #       documentation will be highlighted in yellow.
          #
          # https://getbootstrap.com/docs/4.0/content/tables/
          message = "Invalid data for Spotlight::SolrDocumentSidecar for document_id=#{sidecar_id}"
          job_tracker.append_log_entry(type: :warning, exhibit: exhibit, message: message)
          job_tracker.append_log_entry(type: :warning, exhibit: exhibit, message: e.message)
          total_warnings += 1
        end
      rescue StandardError => e
        message = "An error has occurred when trying to index the URN for document_id=#{sidecar_id}"
        job_tracker.append_log_entry(type: :warning, exhibit: exhibit, message: message)
        job_tracker.append_log_entry(type: :warning, exhibit: exhibit, message: %(#{e.class}: #{e.message}))
        total_warnings += 1
      end
      total_warnings
    end
  end
end
