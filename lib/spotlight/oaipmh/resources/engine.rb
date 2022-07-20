require 'spotlight/engine'

module Spotlight::Oaipmh::Resources
  class Engine < ::Rails::Engine
    Spotlight::Oaipmh::Resources::Engine.config.resource_partial = 'spotlight/resources/oaipmh_harvester/form'

    initializer :append_migrations do |app|
      if !app.root.to_s.match(root.to_s) && app.root.join('db/migrate').children.none? { |path| path.fnmatch?("*.spotlight-oaipmh-resources.rb") }
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    initializer 'spotlight.oaipmh.initialize' do
      Spotlight::Engine.config.external_resources_partials ||= []
      Spotlight::Engine.config.external_resources_partials << Spotlight::Oaipmh::Resources::Engine.config.resource_partial
    end
    config.generators do |g|
      g.test_framework :rspec
    end
  end
end
