require 'spotlight/oaipmh/resources/version'
require 'spotlight'
require 'active_support/all'
require "spotlight/oaipmh/resources/engine"

module Spotlight
  module Oaipmh
    module Resources
      mattr_accessor :standard_spotlight_fields, :use_iiif_images, :download_full_image

      self.download_full_image = false
      self.standard_spotlight_fields = ['unique-id_tesim', 'full_title_tesim', 'spotlight_upload_description_tesim', 'thumbnail_url_ssm', 'full_image_url_ssm', 'spotlight_upload_date_tesim"', 'spotlight_upload_attribution_tesim']
      self.use_iiif_images = true

      # this function maps the vars from your app into your engine
      def self.setup
        yield self
      end
    end
  end
end
