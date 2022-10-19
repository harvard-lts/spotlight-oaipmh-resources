
module Spotlight::Resources
  class HarvesterController < Spotlight::ApplicationController

    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit

    # POST /harvester
    def create

      my_params = resource_params

      #upload the mapping file if it exists
      if (my_params.has_key?(:custom_mapping))
        upload
        my_params.delete(:custom_mapping)
      end
      mapping_file = resource_params[:mods_mapping_file]
      if (resource_params[:type] == Spotlight::HarvestType::SOLR)
        mapping_file = resource_params[:solr_mapping_file]
        harvester = Spotlight::SolrHarvester.new(
          base_url: resource_params[:url],
          set: resource_params[:set],
          mapping_file: mapping_file,
          exhibit: current_exhibit
        )
      else
        harvester = Spotlight::OaipmhHarvester.new(
          base_url: resource_params[:url],
          set: resource_params[:set],
          mapping_file: mapping_file,
          exhibit: current_exhibit
        )
      end
      # TODO: handle
      if (resource_params.has_key?(:custom_mapping))
        mapping_file = resource_params[:custom_mapping].original_filename
      end

      if harvester.save
        Spotlight::Resources::PerformHarvestsJob.perform_later(harvester: harvester, user: current_user)
        flash[:notice] = t('spotlight.resources.harvester.performharvest.success', set: resource_params[:set])
      else
        flash[:error] = "Failed to create harvester for #{resource_params[:set]}. #{harvester.errors.full_messages.to_sentence}"
      end
      redirect_to spotlight.admin_exhibit_catalog_path(current_exhibit, sort: :timestamp)
    end

  private

    def upload
      name = resource_params[:custom_mapping].original_filename
      Dir.mkdir("public/uploads") unless Dir.exist?("public/uploads")
      dir = "public/uploads/modsmapping"
      if (resource_params[:type]  == Spotlight::HarvestType::SOLR)
        dir = "public/uploads/solrmapping"
      end
      Dir.mkdir(dir) unless Dir.exist?(dir)

      path = File.join(dir, name)
      File.open(path, "w") { |f| f.write(resource_params[:custom_mapping].read) }
    end


    def resource_params
      params.require(:harvester).permit(:type, :url, :set, :mods_mapping_file, :solr_mapping_file, :custom_mapping)
    end
  end
end
