# frozen_string_literal: true

class CreateCropFertilizeProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :crop_fertilize_profiles do |t|
      t.references :crop, null: false, foreign_key: true, index: true
      # totals: 総肥料量（g/m²）
      t.float :total_n, null: false, comment: "Total nitrogen (g/m²)"
      t.float :total_p, null: false, comment: "Total phosphorus (g/m²)"
      t.float :total_k, null: false, comment: "Total potassium (g/m²)"
      # sources: 情報源（JSON配列）
      t.text :sources, comment: "Information sources (JSON array)"
      # confidence: 信頼度（0-1）
      t.float :confidence, null: false, default: 0.5, comment: "Confidence level (0-1)"
      # notes: 追加のガイダンス
      t.text :notes, comment: "Additional guidance"

      t.timestamps
    end
  end
end

