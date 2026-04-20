# frozen_string_literal: true

class CreateNutrientRequirements < ActiveRecord::Migration[7.1]
  def change
    create_table :nutrient_requirements do |t|
      t.references :crop_stage, null: false, foreign_key: true
      t.float :daily_uptake_n         # 窒素の日当たり吸収量 (g/m²/day)
      t.float :daily_uptake_p         # リン（元素）の日当たり吸収量 (g/m²/day)
      t.float :daily_uptake_k         # カリウム（元素）の日当たり吸収量 (g/m²/day)
      t.timestamps
    end
  end
end
