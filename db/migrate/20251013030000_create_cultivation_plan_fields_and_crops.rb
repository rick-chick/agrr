# frozen_string_literal: true

class CreateCultivationPlanFieldsAndCrops < ActiveRecord::Migration[8.0]
  def change
    # 作付け計画専用の圃場テーブル
    create_table :cultivation_plan_fields do |t|
      t.references :cultivation_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.float :area, null: false
      t.float :daily_fixed_cost
      t.text :description
      t.timestamps
    end
    
    # 作付け計画専用の作物テーブル
    create_table :cultivation_plan_crops do |t|
      t.references :cultivation_plan, null: false, foreign_key: true
      t.string :name, null: false
      t.string :variety
      t.float :area_per_unit
      t.float :revenue_per_area
      t.string :agrr_crop_id
      t.timestamps
    end
    
    # field_cultivationsテーブルを更新
    # 既存のfield_id, crop_idの代わりに、
    # cultivation_plan_field_id, cultivation_plan_crop_idを使用
    add_reference :field_cultivations, :cultivation_plan_field, foreign_key: true
    add_reference :field_cultivations, :cultivation_plan_crop, foreign_key: true
    
    # 既存のカラムから追加したカラムは削除（前回のマイグレーションで追加したもの）
    remove_column :field_cultivations, :field_name, :string
    remove_column :field_cultivations, :field_area, :float
    remove_column :field_cultivations, :daily_fixed_cost, :float
    remove_column :field_cultivations, :crop_name, :string
    remove_column :field_cultivations, :crop_variety, :string
    remove_column :field_cultivations, :crop_area_per_unit, :float
    remove_column :field_cultivations, :crop_revenue_per_area, :float
    remove_column :field_cultivations, :crop_agrr_id, :string
  end
end

