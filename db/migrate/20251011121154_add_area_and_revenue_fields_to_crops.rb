class AddAreaAndRevenueFieldsToCrops < ActiveRecord::Migration[8.0]
  def change
    add_column :crops, :area_per_unit, :float
    add_column :crops, :revenue_per_area, :float
  end
end
