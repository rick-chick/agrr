class AddRegionIdToFarms < ActiveRecord::Migration[8.0]
  def change
    add_reference :farms, :region, null: false, foreign_key: true
  end
end
