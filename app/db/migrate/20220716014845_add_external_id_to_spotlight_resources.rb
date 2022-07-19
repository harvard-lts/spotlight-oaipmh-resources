class AddExternalIdToSpotlightResources < ActiveRecord::Migration[6.1]
  def change
    add_column :spotlight_resources, :external_id, :string
  end
end
