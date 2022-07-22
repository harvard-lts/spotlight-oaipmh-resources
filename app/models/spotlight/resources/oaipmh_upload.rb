# frozen_string_literal: true

module Spotlight
  module Resources
    ##
    # Exhibit-specific resources, created using uploaded and custom fields
    class OaipmhUpload < Spotlight::Resources::Upload
      def attach_image
        return if self.data['full_image_url_ssm'].blank?
        image = self.upload || self.create_upload
        image.remote_image_url = self.data['full_image_url_ssm']
        iiif_tilesource = riiif.info_path(image)
        image.update(iiif_tilesource: iiif_tilesource)
      end

      def riiif
        Riiif::Engine.routes.url_helpers
      end
    end
  end
end
