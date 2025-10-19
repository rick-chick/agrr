# frozen_string_literal: true

class CreateFreeCropPlans < ActiveRecord::Migration[8.0]
  def change
    create_table :free_crop_plans do |t|
      t.references :farm, null: false, foreign_key: true
      t.references :crop, null: false, foreign_key: true
      t.string :session_id
      t.integer :area_sqm, null: false
      t.string :status, default: 'pending', null: false
      t.text :plan_data

      t.timestamps
    end

    add_index :free_crop_plans, :session_id
    add_index :free_crop_plans, :status
  end
end

