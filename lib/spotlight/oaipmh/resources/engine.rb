require 'spotlight/engine'

module Spotlight::Oaipmh::Resources
  class Engine < ::Rails::Engine
    Spotlight::Oaipmh::Resources::Engine.config.resource_partial = 'spotlight/resources/oaipmh_harvester/form'
    
    initializer 'spotlight.oaipmh.initialize' do
      Spotlight::Engine.config.external_resources_partials ||= []
      Spotlight::Engine.config.external_resources_partials << Spotlight::Oaipmh::Resources::Engine.config.resource_partial
    end
    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
