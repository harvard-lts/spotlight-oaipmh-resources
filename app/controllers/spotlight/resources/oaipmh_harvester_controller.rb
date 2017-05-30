module Spotlight::Resources
  class OaipmhHarvesterController < Spotlight::ApplicationController
    
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    before_action :build_resource
    
    # POST /oaipmh_harvester
    def create
      
      my_params = resource_params
      
      #upload the mapping file if it exists
      if (my_params.has_key?(:custom_mapping))
        upload
        my_params.delete(:custom_mapping)
      end
      @resource.attributes = my_params
      if @resource.save_and_index
        #Create delayed job
        
        redirect_to spotlight.admin_exhibit_catalog_path(current_exhibit, sort: :timestamp)
      else
        flash[:error] = @resource.errors.values.join(', ') if @resource.errors.present?
        redirect_to spotlight.new_exhibit_resource_path(current_exhibit)
      end
    end
    
  private
    
    def upload
      name = resource_params[:custom_mapping].original_filename
      dir = "public/uploads/modsmapping"
      Dir.mkdir(dir) unless Dir.exist?(dir)
      
      path = File.join(dir, name)
      File.open(path, "w") { |f| f.write(resource_params[:custom_mapping].read) }
    end


    def resource_params
      params.require(:resources_oaipmh_harvester).permit(:url, :set, :mapping_file, :custom_mapping)
    end
    
    def build_resource
      mapping_file = resource_params[:mapping_file]
      if (resource_params.has_key?(:custom_mapping))
        mapping_file = resource_params[:custom_mapping].original_filename
      end
      @resource ||= Spotlight::Resources::OaipmhHarvester.create(
        url: resource_params[:url],
        data: {base_url: resource_params[:url],
          set: resource_params[:set],
          mapping_file: mapping_file},
        exhibit: current_exhibit)
    end
  end

end
