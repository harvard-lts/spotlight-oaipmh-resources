require 'rails/generators'

module Spotlight
  module Oaipmh
    module Resources
      # :nodoc:
      class InstallGenerator < Rails::Generators::Base
        desc 'This generator mounts the Spotlight::Oaipmh::Resources::Engine engine'

        def inject_spotlight_oaipmh_resources_routes
          route "mount Spotlight::Oaipmh::Resources::Engine, at: 'spotlight_oaipmh_resources'"
        end
      end
    end
  end
end
