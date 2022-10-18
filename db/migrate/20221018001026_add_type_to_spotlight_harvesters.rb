class AddTypeToSpotlightHarvesters < ActiveRecord::Migration[6.1]
  def up
    add_column :spotlight_harvesters, :type, :string

    Spotlight::Harvester.find_each do |harvester|
      next if harvester.type.present?

      harvester.type = 'Spotlight::OaipmhHarvester'
      harvester.save!
    end

    change_column_null :spotlight_harvesters, :type, false
  end

  def down
    remove_column :spotlight_harvesters, :type
  end
end
