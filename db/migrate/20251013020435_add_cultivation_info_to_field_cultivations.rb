# frozen_string_literal: true

class AddCultivationInfoToFieldCultivations < ActiveRecord::Migration[8.0]
  def change
    # 圃場情報カラムを追加
    add_column :field_cultivations, :field_name, :string
    add_column :field_cultivations, :field_area, :float
    add_column :field_cultivations, :daily_fixed_cost, :float
    
    # 作物情報カラムを追加
    add_column :field_cultivations, :crop_name, :string
    add_column :field_cultivations, :crop_variety, :string
    add_column :field_cultivations, :crop_area_per_unit, :float
    add_column :field_cultivations, :crop_revenue_per_area, :float
    add_column :field_cultivations, :crop_agrr_id, :string
    
    # crop_idをnullableに変更
    change_column_null :field_cultivations, :crop_id, true
    
    # field_idは既にnullableになっている（20251013020434のマイグレーションで対応済み）
  end
end

