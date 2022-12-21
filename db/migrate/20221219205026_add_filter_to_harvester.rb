class AddFilterToHarvester < ActiveRecord::Migration[6.1]
  def change
    add_column :spotlight_harvesters, :filter, :string
  end
end
