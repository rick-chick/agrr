# frozen_string_literal: true

class CreateCultivationPlanStructure < ActiveRecord::Migration[8.0]
  def change
    # CultivationPlans テーブル
    create_table :cultivation_plans do |t|
      t.references :farm, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :session_id, index: true
      t.float :total_area, null: false
      t.string :status, default: 'pending', null: false, index: true
      t.text :error_message
      t.timestamps
    end
    
    # FieldCultivations テーブル
    create_table :field_cultivations do |t|
      t.references :cultivation_plan, null: false, foreign_key: true
      t.references :field, null: false, foreign_key: true
      t.references :crop, null: false, foreign_key: true
      t.float :area, null: false
      t.date :start_date
      t.date :completion_date
      t.integer :cultivation_days
      t.float :estimated_cost
      t.string :status, default: 'pending', null: false, index: true
      t.text :optimization_result
      t.timestamps
    end
    
    add_index :field_cultivations, [:cultivation_plan_id, :field_id]
  end
end
