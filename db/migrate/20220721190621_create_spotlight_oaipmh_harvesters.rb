class CreateSpotlightOaipmhHarvesters < ActiveRecord::Migration[6.1]
  def change
    create_table :spotlight_oaipmh_harvesters do |t|
      t.references :exhibit
      t.string :base_url
      t.string :set
      t.string :mapping_file

      t.timestamps
    end
  end
end
