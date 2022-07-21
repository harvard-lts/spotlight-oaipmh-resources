
module Spotlight::Resources
  class OaipmhHarvesterController < Spotlight::ApplicationController
    
    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit
    
    # POST /oaipmh_harvester
    def create
      
      my_params = resource_params
      
      #upload the mapping file if it exists
      if (my_params.has_key?(:custom_mapping))
        upload
        my_params.delete(:custom_mapping)
      end
      mapping_file = resource_params[:mapping_file]
      if (resource_params.has_key?(:custom_mapping))
              mapping_file = resource_params[:custom_mapping].original_filename
      end
      harvester = Spotlight::Resources::OaipmhHarvester.create(
        url: resource_params[:url],
        data: {
          base_url: resource_params[:url],
          set: resource_params[:set],
          mapping_file: mapping_file
        },
        exhibit: current_exhibit
      )

      if harvester.save
        Spotlight::Resources::PerformHarvestsJob.perform_later(harvester: harvester, user: current_user)
        flash[:notice] = t('spotlight.resources.oaipmh_harvester.performharvest.success', set: resource_params[:set])
      else
        Spotlight::HarvestingCompleteMailer.harvest_failed(resource_params[:set], current_exhibit, current_user).deliver_now
        flash[:error] = "Failed to create harvester for '%{set}'."
      end
      redirect_to spotlight.admin_exhibit_catalog_path(current_exhibit, sort: :timestamp)
    end
    
  private
    
    def upload
      name = resource_params[:custom_mapping].original_filename
      Dir.mkdir("public/uploads") unless Dir.exist?("public/uploads")  
      dir = "public/uploads/modsmapping"
      Dir.mkdir(dir) unless Dir.exist?(dir)
      
      path = File.join(dir, name)
      File.open(path, "w") { |f| f.write(resource_params[:custom_mapping].read) }
    end


    def resource_params
      params.require(:resources_oaipmh_harvester).permit(:url, :set, :mapping_file, :custom_mapping)
    end
  end
end
