module Spotlight::Resources
  class OaipmhHarvesterController < Spotlight::ApplicationController
    
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    before_action :build_resource

    # POST /oaipmh_harvester
    def create
      @resource.attributes = resource_params
      if @resource.save_and_index
        redirect_to spotlight.admin_exhibit_catalog_path(current_exhibit, sort: :timestamp)
      else
        flash[:error] = @resource.errors.values.join(', ') if @resource.errors.present?
        redirect_to spotlight.new_exhibit_resource_path(current_exhibit)
      end
    end


    private

    def resource_params
      params.require(:resources_oaipmh_harvester).permit(:url, :set)
    end
    
    def build_resource
      @resource ||= Spotlight::Resources::OaipmhHarvester.create(
        url: resource_params[:url],
        data: {base_url: resource_params[:url],
        set: resource_params[:set]},
        exhibit: current_exhibit
      )
    end
  end
end
