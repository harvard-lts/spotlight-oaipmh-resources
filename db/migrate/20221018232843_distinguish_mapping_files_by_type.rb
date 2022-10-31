class DistinguishMappingFilesByType < ActiveRecord::Migration[6.1]
  def change
    rename_column :spotlight_harvesters, :mapping_file, :mods_mapping_file
    add_column :spotlight_harvesters, :solr_mapping_file, :string
  end
end
