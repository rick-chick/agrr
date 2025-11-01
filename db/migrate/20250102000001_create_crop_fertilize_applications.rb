# frozen_string_literal: true

class CreateCropFertilizeApplications < ActiveRecord::Migration[8.0]
  def change
    create_table :crop_fertilize_applications do |t|
      t.references :crop_fertilize_profile, null: false, foreign_key: true
      # application_type: "basal" (基肥) または "topdress" (追肥)
      t.string :application_type, null: false, comment: "Type: 'basal' or 'topdress'"
      # count: 施用回数
      t.integer :count, null: false, default: 1, comment: "Number of applications"
      # schedule_hint: タイミングのガイダンス
      t.string :schedule_hint, comment: "Timing guidance (e.g., 'pre-plant', 'fruiting')"
      # nutrients: このタイプの総量（g/m²）
      t.float :total_n, null: false, comment: "Total nitrogen for this type (g/m²)"
      t.float :total_p, null: false, comment: "Total phosphorus for this type (g/m²)"
      t.float :total_k, null: false, comment: "Total potassium for this type (g/m²)"
      # per_application: 1回あたりの量（g/m²、追肥の場合のみ）
      t.float :per_application_n, comment: "Nitrogen per application (g/m²)"
      t.float :per_application_p, comment: "Phosphorus per application (g/m²)"
      t.float :per_application_k, comment: "Potassium per application (g/m²)"

      t.timestamps
    end

    # インデックス
    add_index :crop_fertilize_applications, :crop_fertilize_profile_id
    add_index :crop_fertilize_applications, :application_type
    
    # application_typeのバリデーションはモデルで行う
  end
end

