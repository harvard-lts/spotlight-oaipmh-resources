Spotlight::Oaipmh::Resources::Engine.routes.draw do
  resources :exhibits, path: '/', only: [] do
      resource :oaipmh_harvester, controller: :"spotlight/resources/oaipmh_harvester", only: [:create, :update]
    end
end
