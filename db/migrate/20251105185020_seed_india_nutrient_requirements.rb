# frozen_string_literal: true

class SeedIndiaNutrientRequirements < ActiveRecord::Migration[8.0]
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
    say "🌱 Seeding India (in) reference nutrient requirements..."
    seed_india_nutrient_requirements
    say "✅ India reference nutrient requirements seeding completed!"
  end

  def down
    say "🗑️  Removing India (in) reference nutrient requirements..."
    TempNutrientRequirement.where(region: 'in', is_reference: true).delete_all
    say "✅ India reference nutrient requirements removed"
  end

  private

  def seed_india_nutrient_requirements
    say_with_time "Creating reference nutrient requirements..." do
      in_crops = TempCrop.where(region: 'in', is_reference: true)
      crop_id_to_name = in_crops.pluck(:id, :name).to_h

      in_crop_ids = in_crops.pluck(:id)
      in_crop_stages = TempCropStage.where(crop_id: in_crop_ids)

      count = 0
      in_crop_stages.each do |stage|
        crop_name = crop_id_to_name[stage.crop_id]
        next unless crop_name

        # Sample data: values based on stage name and order
        # Actual values should be adjusted later
        nutrient_data = calculate_nutrient_values(crop_name, stage.name, stage.order)

        nutrient = TempNutrientRequirement.find_or_initialize_by(
          crop_stage_id: stage.id,
          region: 'in',
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
    # Sample data: values based on crop and stage
    # Actual values should be adjusted later

    # Base values (g/m²/day)
    base_n = 0.5
    base_p = 0.2
    base_k = 0.3

    # Multiplier based on stage (increases with growth)
    multiplier = case stage_order
    when 1 then 0.3  # Early
    when 2 then 0.6  # Growth
    when 3 then 1.0  # Peak
    when 4 then 0.8  # Maturity
    else 0.5
    end

    # Crop-specific adjustments (Hindi crop names)
    crop_multiplier = case crop_name
    # Fruit vegetables
    when 'टमाटर (पूसा रूबी)', 'बैंगन (बैंगन)', 'मिर्च (गुंटूर)' then 1.2
    # Leaf vegetables
    when 'पत्ता गोभी (गोल्डन एकर)', 'फूल गोभी (स्नोबॉल)' then 1.1
    # Root vegetables
    when 'आलू (कुफरी)', 'प्याज (नासिक लाल)', 'अदरक (रियो)', 'हल्दी (अल्लेप्पी)' then 0.9
    # Cereals/Grains
    when 'चावल (IR64)', 'चावल (बासमती)', 'गेहूं (HD2967)', 'मक्का (संकर)',
                           'ज्वार (ज्वार अनाज)', 'बाजरा (मोती बाजरा)' then 1.0
    # Pulses/Legumes
    when 'अरहर (तूर दाल)', 'चना (देसी)', 'मसूर (मसूर दाल)', 'सोयाबीन (JS335)',
                           'मूंगफली (TMV2)' then 1.0
    # Fruits
    when 'आम (अल्फांसो)', 'नारियल (लंबा)' then 1.1
    # Industrial crops
    when 'कपास (बीटी कपास)', 'गन्ना (CoC671)', 'जूट (JRO524)' then 1.0
    # Spices
    when 'इलायची (मालाबार)' then 1.1
    # Beverages
    when 'कॉफी (अरेबिका)', 'चाय (असम)' then 1.1
    # Oil crops
    when 'सरसों (पूसा बोल्ड)', 'सूरजमुखी (KBSH44)' then 1.0
    else 1.0
    end

    {
      n: (base_n * multiplier * crop_multiplier).round(2),
      p: (base_p * multiplier * crop_multiplier).round(2),
      k: (base_k * multiplier * crop_multiplier).round(2)
    }
  end
end
