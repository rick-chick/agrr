# frozen_string_literal: true

namespace :db do
  desc "Fix missing region data in existing records"
  task fix_region_data: :environment do
    puts "🔧 Fixing missing region data..."
    
    # Update farms without region
    farms_updated = 0
    Farm.where(region: nil).where(is_reference: true).find_each do |farm|
      # 日本の参照農場（既存データは全て日本）
      farm.update_column(:region, "jp")
      farms_updated += 1
    end
    puts "✅ Updated #{farms_updated} farms to region: jp"
    
    # Update crops without region
    crops_updated = 0
    Crop.where(region: nil).where(is_reference: true).find_each do |crop|
      crop.update_column(:region, "jp")
      crops_updated += 1
    end
    puts "✅ Updated #{crops_updated} crops to region: jp"
    
    # Update fields without region
    fields_updated = 0
    Field.where(region: nil).find_each do |field|
      field.update_column(:region, "jp")
      fields_updated += 1
    end
    puts "✅ Updated #{fields_updated} fields to region: jp"
    
    # Update interaction_rules without region
    rules_updated = 0
    InteractionRule.where(region: nil).where(is_reference: true).find_each do |rule|
      rule.update_column(:region, "jp")
      rules_updated += 1
    end
    puts "✅ Updated #{rules_updated} interaction rules to region: jp"
    
    puts "🎉 Region data fix completed!"
  end
end

