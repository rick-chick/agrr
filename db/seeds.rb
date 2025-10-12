# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "🌱 Seeding database..."

# Regions（地域）
puts "Creating regions..."
regions = [
  { name: '日本', country_code: 'JP', active: true },
  { name: 'アメリカ', country_code: 'US', active: true },
  { name: 'イギリス', country_code: 'UK', active: true },
  { name: 'フランス', country_code: 'FR', active: true },
  { name: 'ドイツ', country_code: 'DE', active: true },
  { name: 'イタリア', country_code: 'IT', active: true },
  { name: 'スペイン', country_code: 'ES', active: true },
  { name: 'オーストラリア', country_code: 'AU', active: true },
  { name: 'カナダ', country_code: 'CA', active: true },
  { name: 'ブラジル', country_code: 'BR', active: true }
]

regions.each do |region_data|
  Region.find_or_create_by!(name: region_data[:name]) do |region|
    region.country_code = region_data[:country_code]
    region.active = region_data[:active]
  end
end
puts "✅ Created #{Region.count} regions"

# Farm Sizes（農場サイズ）
puts "Creating farm sizes..."
farm_sizes = [
  { name: '極小規模', area_sqm: 5, display_order: 1, active: true },
  { name: '小規模', area_sqm: 20, display_order: 2, active: true },
  { name: '中規模', area_sqm: 100, display_order: 3, active: true },
  { name: '大規模', area_sqm: 500, display_order: 4, active: true }
]

farm_sizes.each do |farm_size_data|
  FarmSize.find_or_create_by!(name: farm_size_data[:name]) do |farm_size|
    farm_size.area_sqm = farm_size_data[:area_sqm]
    farm_size.display_order = farm_size_data[:display_order]
    farm_size.active = farm_size_data[:active]
  end
end
puts "✅ Created #{FarmSize.count} farm sizes"

# Reference Crops（参照用作物）
puts "Creating reference crops..."
reference_crops = [
  { name: 'トマト', variety: '大玉', is_reference: true },
  { name: 'ジャガイモ', variety: '男爵', is_reference: true },
  { name: '玉ねぎ', variety: '黄玉ねぎ', is_reference: true },
  { name: 'キャベツ', variety: '春キャベツ', is_reference: true },
  { name: 'ニンジン', variety: '五寸ニンジン', is_reference: true },
  { name: 'レタス', variety: '結球レタス', is_reference: true },
  { name: 'ほうれん草', variety: '一般', is_reference: true },
  { name: 'ナス', variety: '千両二号', is_reference: true },
  { name: 'キュウリ', variety: '白イボ', is_reference: true },
  { name: 'ピーマン', variety: '京みどり', is_reference: true },
  { name: '大根', variety: '青首大根', is_reference: true },
  { name: 'ブロッコリー', variety: '一般', is_reference: true },
  { name: '白菜', variety: '結球白菜', is_reference: true },
  { name: 'とうもろこし', variety: 'スイートコーン', is_reference: true },
  { name: 'かぼちゃ', variety: '西洋かぼちゃ', is_reference: true }
]

reference_crops.each do |crop_data|
  Crop.find_or_create_by!(name: crop_data[:name], variety: crop_data[:variety], is_reference: true) do |crop|
    crop.user_id = nil
    crop.is_reference = crop_data[:is_reference]
  end
end
puts "✅ Created #{Crop.reference.count} reference crops"

puts "🎉 Seeding completed!"
puts ""
puts "Summary:"
puts "  Regions: #{Region.count}"
puts "  Farm Sizes: #{FarmSize.count}"
puts "  Reference Crops: #{Crop.reference.count}"



