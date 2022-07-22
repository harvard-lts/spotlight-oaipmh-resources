# frozen_string_literal: true

module Spotlight
  module Resources
    ##
    # Exhibit-specific resources, created using uploaded and custom fields
    class OaiUpload < Spotlight::Resources::Upload
      # this sets the path for Oai Uploads from the Harvester to include the URN (aka unique-id) as opposed to the spotlight generated ID. external_id already contains the exhibit_id at the beginning.
      def compound_id
        "#{external_id}"
      end
    end
  end
end