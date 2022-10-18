class RenameSpotlightOaipmhHarvestersToSpotlightHarvesters < ActiveRecord::Migration[6.1]
  def change
    rename_table :spotlight_oaipmh_harvesters, :spotlight_harvesters
  end
end
