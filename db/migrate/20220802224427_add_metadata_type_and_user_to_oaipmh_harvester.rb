class AddMetadataTypeAndUserToOaipmhHarvester < ActiveRecord::Migration[6.1]
  def change
    change_table :spotlight_oaipmh_harvesters do |t|
      t.references :user
      t.string :metadata_type
    end
  end
end
