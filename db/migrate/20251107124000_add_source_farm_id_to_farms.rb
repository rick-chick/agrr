# frozen_string_literal: true

class AddSourceFarmIdToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :source_farm_id, :integer
    add_index :farms, [:user_id, :source_farm_id], unique: true, where: "source_farm_id IS NOT NULL"
  end
end




