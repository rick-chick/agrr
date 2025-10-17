# frozen_string_literal: true

class AddRegionToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :region, :string
    add_index :farms, :region
  end
end

