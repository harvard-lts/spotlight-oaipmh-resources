
module Spotlight::Resources
  class HarvesterController < Spotlight::ApplicationController

    load_and_authorize_resource :exhibit, class: Spotlight::Exhibit

    # POST /harvester
    def create
      upload if resource_params.has_key?(:custom_mapping)

      harvester = build_harvester_by_type(resource_params[:type])
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

    def build_harvester_by_type(type)
      if type == Spotlight::HarvestType::MODS
        Spotlight::OaipmhHarvester.new(
          base_url: resource_params[:url],
          set: resource_params[:set],
          mods_mapping_file: mapping_file(type),
          exhibit: current_exhibit
        )
      else
        Spotlight::SolrHarvester.new(
          base_url: resource_params[:url],
          set: resource_params[:set],
          filter: resource_params[:filter],
          solr_mapping_file: mapping_file(type),
          exhibit: current_exhibit
        )
      end
    end

    def mapping_file(type)
      return resource_params[:custom_mapping].original_filename if resource_params[:custom_mapping].present?

      mapping_file = if type == Spotlight::HarvestType::MODS
                       resource_params[:mods_mapping_file]
                     else
                       resource_params[:solr_mapping_file]
                     end

      mapping_file
    end

    def resource_params
      params.require(:harvester).permit(:type, :url, :set, :filter, :mods_mapping_file, :solr_mapping_file, :custom_mapping)
    end
  end
end
