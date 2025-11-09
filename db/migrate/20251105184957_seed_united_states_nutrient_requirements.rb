# frozen_string_literal: true

class SeedUnitedStatesNutrientRequirements < ActiveRecord::Migration[8.0]
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
    say "🌱 Seeding United States (us) reference nutrient requirements..."
    seed_us_nutrient_requirements
    say "✅ United States reference nutrient requirements seeding completed!"
  end

  def down
    say "🗑️  Removing United States (us) reference nutrient requirements..."
    TempNutrientRequirement.where(region: 'us', is_reference: true).delete_all
    say "✅ United States reference nutrient requirements removed"
  end

  private

  def seed_us_nutrient_requirements
    say_with_time "Creating reference nutrient requirements..." do
      us_crops = TempCrop.where(region: 'us', is_reference: true)
      crop_id_to_name = us_crops.pluck(:id, :name).to_h
      
      us_crop_ids = us_crops.pluck(:id)
      us_crop_stages = TempCropStage.where(crop_id: us_crop_ids)
      
      count = 0
      us_crop_stages.each do |stage|
        crop_name = crop_id_to_name[stage.crop_id]
        next unless crop_name
        
        # Sample data: values based on stage name and order
        # Actual values should be adjusted later
        nutrient_data = calculate_nutrient_values(crop_name, stage.name, stage.order)
        
        nutrient = TempNutrientRequirement.find_or_initialize_by(
          crop_stage_id: stage.id,
          region: 'us',
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
    
    # Crop-specific adjustments
    crop_multiplier = case crop_name
                      when 'Tomatoes', 'Bell Peppers', 'Cucumbers' then 1.2  # Fruit vegetables
                      when 'Cabbage', 'Broccoli', 'Lettuce' then 1.1  # Leaf vegetables
                      when 'Potatoes', 'Carrots', 'Onions' then 0.9  # Root vegetables
                      when 'Corn', 'Wheat', 'Barley', 'Rice', 'Oats', 'Rye', 'Sorghum' then 1.0  # Cereals
                      when 'Almonds', 'Apples', 'Oranges', 'Grapes', 'Blueberries', 'Pistachios', 'Walnuts' then 1.1  # Fruits/Nuts
                      when 'Cotton', 'Soybeans', 'Peanuts', 'Sugar Beets', 'Sugarcane' then 1.0  # Industrial crops
                      else 1.0
                      end
    
    {
      n: (base_n * multiplier * crop_multiplier).round(2),
      p: (base_p * multiplier * crop_multiplier).round(2),
      k: (base_k * multiplier * crop_multiplier).round(2)
    }
  end
end





