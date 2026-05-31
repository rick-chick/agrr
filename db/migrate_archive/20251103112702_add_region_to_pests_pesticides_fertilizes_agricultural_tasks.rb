# frozen_string_literal: true

class AddRegionToPestsPesticidesFertilizesAgriculturalTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :pests, :region, :string
    add_column :pesticides, :region, :string
    add_column :fertilizes, :region, :string
    add_column :agricultural_tasks, :region, :string

    # 地域によるフィルタリングをサポートするためのインデックス
    add_index :pests, :region
    add_index :pesticides, :region
    add_index :fertilizes, :region
    add_index :agricultural_tasks, :region
  end
end
