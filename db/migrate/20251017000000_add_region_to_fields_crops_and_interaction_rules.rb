# frozen_string_literal: true

class AddRegionToFieldsCropsAndInteractionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :fields, :region, :string
    add_column :crops, :region, :string
    add_column :interaction_rules, :region, :string

    # 地域によるフィルタリングをサポートするためのインデックス
    add_index :fields, :region
    add_index :crops, :region
    add_index :interaction_rules, :region
  end
end

