# frozen_string_literal: true

class AddRegionAndSeedJapanNutrientRequirements < ActiveRecord::Migration[8.0]
  class TempNutrientRequirement < ActiveRecord::Base
    self.table_name = 'nutrient_requirements'
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  class TempCropStage < ActiveRecord::Base
    self.table_name = 'crop_stages'
  end

  def up
    say "🌱 Adding region and is_reference columns to nutrient_requirements..."
    add_column :nutrient_requirements, :region, :string
    add_column :nutrient_requirements, :is_reference, :boolean, default: true, null: false
    add_index :nutrient_requirements, :region
    add_index :nutrient_requirements, :is_reference

    say "🌱 Seeding Japan (jp) reference nutrient requirements..."
    seed_japan_nutrient_requirements
    say "✅ Japan reference nutrient requirements seeding completed!"
  end

  def down
    say "🗑️  Removing Japan (jp) reference nutrient requirements..."
    TempNutrientRequirement.where(region: 'jp', is_reference: true).delete_all
    
    say "🗑️  Removing region and is_reference columns..."
    remove_index :nutrient_requirements, :is_reference
    remove_index :nutrient_requirements, :region
    remove_column :nutrient_requirements, :is_reference
    remove_column :nutrient_requirements, :region
    say "✅ Columns and data removed"
  end

  private

  def seed_japan_nutrient_requirements
    say_with_time "Creating reference nutrient requirements..." do
      jp_crops = TempCrop.where(region: 'jp', is_reference: true)
      crop_id_to_name = jp_crops.pluck(:id, :name).to_h
      
      jp_crop_ids = jp_crops.pluck(:id)
      jp_crop_stages = TempCropStage.where(crop_id: jp_crop_ids)
      
      count = 0
      jp_crop_stages.each do |stage|
        crop_name = crop_id_to_name[stage.crop_id]
        next unless crop_name
        
        # サンプルデータ：ステージ名と順序に基づいて適当な値を設定
        # 実際のデータは後で調整可能
        nutrient_data = calculate_nutrient_values(crop_name, stage.name, stage.order)
        
        nutrient = TempNutrientRequirement.find_or_initialize_by(
          crop_stage_id: stage.id,
          region: 'jp',
          is_reference: true
        )
        
        nutrient.assign_attributes(
          daily_uptake_n: nutrient_data[:n],
          daily_uptake_p: nutrient_data[:p],
          daily_uptake_k: nutrient_data[:k]
        )
        
        nutrient.save!
        count += 1
      end
      count
    end
  end

  def calculate_nutrient_values(crop_name, stage_name, stage_order)
    # サンプルデータ：作物とステージに応じた適当な値を設定
    # 実際の値は後で調整可能
    
    # 基本値（g/m²/day）
    base_n = 0.5
    base_p = 0.2
    base_k = 0.3
    
    # ステージに応じた倍率（成長期に応じて増加）
    multiplier = case stage_order
                 when 1 then 0.3  # 初期
                 when 2 then 0.6  # 成長期
                 when 3 then 1.0  # 最盛期
                 when 4 then 0.8  # 成熟期
                 else 0.5
                 end
    
    # 作物に応じた調整（例）
    crop_multiplier = case crop_name
                      when 'トマト', 'ナス', 'ピーマン' then 1.2  # 果菜類は多め
                      when 'キャベツ', '白菜', 'ブロッコリー' then 1.1  # 葉菜類
                      when 'ジャガイモ', 'ニンジン', '大根', '玉ねぎ' then 0.9  # 根菜類
                      else 1.0
                      end
    
    {
      n: (base_n * multiplier * crop_multiplier).round(2),
      p: (base_p * multiplier * crop_multiplier).round(2),
      k: (base_k * multiplier * crop_multiplier).round(2)
    }
  end
end
