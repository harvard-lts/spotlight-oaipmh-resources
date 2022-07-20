require 'spotlight/oaipmh/resources/version'
require 'spotlight'


module Spotlight
  module Oaipmh
    module Resources
      require "spotlight/oaipmh/resources/engine"
      class << self
        mattr_accessor :standard_spotlight_fields,
          :use_iiif_images

        self.use_iiif_images = true
        self.standard_spotlight_fields = ['unique-id_tesim', 'full_title_tesim', 'spotlight_upload_description_tesim', 'thumbnail_url_ssm', 'full_image_url_ssm', 'spotlight_upload_date_tesim"', 'spotlight_upload_attribution_tesim']
      end

      # this function maps the vars from your app into your engine
      def self.setup
        yield self
      end
    end
  end
end
