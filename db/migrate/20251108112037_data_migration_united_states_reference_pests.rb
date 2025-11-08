# frozen_string_literal: true

class DataMigrationUnitedStatesReferencePests < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計
  
  class TempPest < ActiveRecord::Base
    self.table_name = 'pests'
    has_one :pest_temperature_profile, class_name: 'DataMigrationUnitedStatesReferencePests::TempPestTemperatureProfile', foreign_key: 'pest_id'
    has_one :pest_thermal_requirement, class_name: 'DataMigrationUnitedStatesReferencePests::TempPestThermalRequirement', foreign_key: 'pest_id'
    has_many :pest_control_methods, class_name: 'DataMigrationUnitedStatesReferencePests::TempPestControlMethod', foreign_key: 'pest_id'
    has_many :crop_pests, class_name: 'DataMigrationUnitedStatesReferencePests::TempCropPest', foreign_key: 'pest_id'
  end
  
  class TempPestTemperatureProfile < ActiveRecord::Base
    self.table_name = 'pest_temperature_profiles'
    belongs_to :pest, class_name: 'DataMigrationUnitedStatesReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestThermalRequirement < ActiveRecord::Base
    self.table_name = 'pest_thermal_requirements'
    belongs_to :pest, class_name: 'DataMigrationUnitedStatesReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestControlMethod < ActiveRecord::Base
    self.table_name = 'pest_control_methods'
    belongs_to :pest, class_name: 'DataMigrationUnitedStatesReferencePests::TempPest', foreign_key: 'pest_id'
  end
  
  class TempCropPest < ActiveRecord::Base
    self.table_name = 'crop_pests'
    belongs_to :pest, class_name: 'DataMigrationUnitedStatesReferencePests::TempPest', foreign_key: 'pest_id'
    belongs_to :crop, class_name: 'DataMigrationUnitedStatesReferencePests::TempCrop', foreign_key: 'crop_id'
  end
  
  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end
  
  def up
    say "🌱 Seeding United States (us) reference pests..."
    
    seed_reference_pests
    
    say "✅ United States reference pests seeding completed!"
  end
  
  def down
    say "🗑️  Removing United States (us) reference pests..."
    
    # Find pests by region
    pest_ids = TempPest.where(region: 'us', is_reference: true).pluck(:id)
    
    # Delete related records
    TempCropPest.where(pest_id: pest_ids).delete_all
    TempPestControlMethod.where(pest_id: pest_ids).delete_all
    TempPestThermalRequirement.where(pest_id: pest_ids).delete_all
    TempPestTemperatureProfile.where(pest_id: pest_ids).delete_all
    TempPest.where(region: 'us', is_reference: true).delete_all
    
    say "✅ United States reference pests removed"
  end
  
  private
  
  def seed_reference_pests
      # Spotted Lanternfly
      pest = TempPest.find_or_initialize_by(name: "Spotted Lanternfly", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Lycorma delicatula",
        family: "Fulgoridae",
        order: "Hemiptera",
        description: "The Spotted Lanternfly feeds on the sap of plants, causing wilting, leaf drop, and reduced vigor in affected crops. It can lead to significant damage to apples by weakening the trees and making them more susceptible to disease.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Use of chemical insecticides to control adult and nymph populations.",
        timing_hint: "Apply during the early stages of infestation."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Encouraging natural predators such as parasitic wasps to control populations.",
        timing_hint: "Introduce predators in the spring."
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "Tree Banding",
        description: "Using sticky bands around tree trunks to trap nymphs and adults.",
        timing_hint: "Install bands in early spring before nymphs emerge."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Host Plant Removal",
        description: "Removing preferred host plants to reduce population density.",
        timing_hint: "Conduct removals in late fall or early spring."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Apples", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Japanese Beetle
      pest = TempPest.find_or_initialize_by(name: "Japanese Beetle", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Popillia japonica",
        family: "Scarabaeidae",
        order: "Coleoptera",
        description: "The Japanese Beetle causes significant damage to a variety of crops by feeding on leaves, flowers, and fruits. Infestations can lead to defoliation and reduced yield in affected plants.",
        occurrence_season: "Late spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1500,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to control adult beetles and larvae.",
        timing_hint: "Apply during peak adult activity in late spring to early summer."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Nematodes",
        description: "Use beneficial nematodes to target larvae in the soil.",
        timing_hint: "Apply in early spring when larvae are present."
      )
      pest.pest_control_methods.create!(
        method_type: "physical",
        method_name: "Handpicking",
        description: "Manually remove beetles from plants.",
        timing_hint: "Best done in the morning when beetles are less active."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the beetle.",
        timing_hint: "Implement annually to reduce beetle populations."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Apples", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Potatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Bell Peppers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Broccoli", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cabbage", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Carrots", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Blueberries", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Grapes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Lettuce", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Oats", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Onions", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Oranges", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Peanuts", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Pistachios", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Sugar Beets", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Sugarcane", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Strawberries", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Walnuts", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Watermelon", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Wheat", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Citrus Longhorned Beetle
      pest = TempPest.find_or_initialize_by(name: "Citrus Longhorned Beetle", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Anoplophora chinensis",
        family: "Cerambycidae",
        order: "Coleoptera",
        description: "The Citrus Longhorned Beetle primarily damages citrus trees by boring into the wood, which can lead to tree decline and death. Infestations can cause significant damage to oranges and tomatoes, affecting their growth and yield.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticide application",
        description: "Apply systemic insecticides to control larvae within the tree.",
        timing_hint: "Apply during early spring when beetles emerge."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural predators",
        description: "Encourage natural predators such as birds and beneficial insects to reduce beetle populations.",
        timing_hint: "Throughout the growing season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Sanitation",
        description: "Remove and destroy infested plant material to prevent spread.",
        timing_hint: "After harvest and before new growth."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Oranges", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Colorado Potato Beetle
      pest = TempPest.find_or_initialize_by(name: "Colorado Potato Beetle", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Leptinotarsa decemlineata",
        family: "Chrysomelidae",
        order: "Coleoptera",
        description: "The Colorado Potato Beetle primarily feeds on the leaves of potato and tomato plants, causing significant defoliation and reducing crop yields.",
        occurrence_season: "Spring to early fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to control adult beetles and larvae.",
        timing_hint: "Apply when beetles are first observed."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as ladybugs to help control beetle populations.",
        timing_hint: "Release beneficial insects early in the season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the beetle.",
        timing_hint: "Implement rotation annually."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Potatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Corn Rootworm
      pest = TempPest.find_or_initialize_by(name: "Corn Rootworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Diabrotica virgifera virgifera",
        family: "Chrysomelidae",
        order: "Coleoptera",
        description: "The Corn Rootworm larvae feed on the roots of corn plants, leading to reduced nutrient uptake, stunted growth, and increased susceptibility to drought and other stresses. Infestations can result in significant yield losses.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Application of insecticides can effectively control adult and larval populations of Corn Rootworm.",
        timing_hint: "Apply at planting or when larvae are detected."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Nematodes",
        description: "Use of beneficial nematodes can help control Corn Rootworm larvae in the soil.",
        timing_hint: "Apply in the spring when larvae are active."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotating corn with non-host crops can disrupt the life cycle of Corn Rootworm.",
        timing_hint: "Implement annually to reduce populations."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Aphid
      pest = TempPest.find_or_initialize_by(name: "Aphid", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Aphidoidea",
        family: "Aphididae",
        order: "Hemiptera",
        description: "Aphids are small sap-sucking insects that can cause significant damage to crops such as tomatoes, broccoli, and cabbage by feeding on plant sap, leading to stunted growth, yellowing of leaves, and potential transmission of plant viruses.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 5,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal soap",
        description: "A soap-based pesticide that suffocates aphids on contact.",
        timing_hint: "Apply when aphids are first noticed."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Ladybugs",
        description: "Introduce ladybugs to the garden as they are natural predators of aphids.",
        timing_hint: "Release in early spring when aphids appear."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop rotation",
        description: "Rotate crops each season to disrupt the life cycle of aphids.",
        timing_hint: "Implement at the end of the growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Broccoli", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cabbage", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Whitefly
      pest = TempPest.find_or_initialize_by(name: "Whitefly", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Bemisia tabaci",
        family: "Aleyrodidae",
        order: "Hemiptera",
        description: "Whiteflies feed on the sap of plants, leading to yellowing of leaves, stunted growth, and in severe cases, plant death. They also excrete honeydew, which can lead to sooty mold growth on affected crops.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Soap",
        description: "A soap-based pesticide that suffocates whiteflies on contact.",
        timing_hint: "Apply when whiteflies are first noticed."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Encarsia formosa",
        description: "A parasitic wasp that targets whitefly larvae.",
        timing_hint: "Release during the early stages of whitefly infestation."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Changing the type of crops grown in a particular area to disrupt the life cycle of whiteflies.",
        timing_hint: "Implement at the end of the growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cucumbers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Thrips
      pest = TempPest.find_or_initialize_by(name: "Thrips", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Thysanoptera",
        family: "Thripidae",
        order: "Thysanoptera",
        description: "Thrips cause damage by feeding on the sap of plants, leading to discoloration, stunted growth, and in severe cases, plant death. They can also transmit plant viruses, further exacerbating crop damage.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Soap",
        description: "A soap-based pesticide that suffocates thrips on contact.",
        timing_hint: "Apply during early morning or late evening for best results."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Predatory Mites",
        description: "Introduce predatory mites that feed on thrips.",
        timing_hint: "Release during the early stages of thrips infestation."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of thrips.",
        timing_hint: "Implement at the end of the growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cucumbers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Strawberries", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Spider Mite
      pest = TempPest.find_or_initialize_by(name: "Spider Mite", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Tetranychus urticae",
        family: "Tetranychidae",
        order: "Acari",
        description: "Spider mites cause damage by feeding on the undersides of leaves, leading to stippling, yellowing, and eventual leaf drop. Infestations can result in reduced plant vigor and yield.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Acaricides",
        description: "Chemical treatments specifically targeting mites.",
        timing_hint: "Apply when mites are first detected."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Predatory Mites",
        description: "Introduce natural predators to control spider mite populations.",
        timing_hint: "Release during early infestation stages."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of spider mites.",
        timing_hint: "Implement annually."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cucumbers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Cutworm
      pest = TempPest.find_or_initialize_by(name: "Cutworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Agrotis spp.",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "Cutworms are known to cause significant damage to young plants by cutting them at the base, leading to wilting and death. They primarily affect seedlings and can devastate crops like corn and soybeans.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to control cutworm populations effectively.",
        timing_hint: "Apply during early stages of crop growth."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Nematodes",
        description: "Introduce beneficial nematodes to target cutworm larvae in the soil.",
        timing_hint: "Apply in the spring when cutworm activity begins."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of cutworms.",
        timing_hint: "Implement before planting season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Armyworm
      pest = TempPest.find_or_initialize_by(name: "Armyworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera frugiperda",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "Armyworms are known to cause significant damage to crops by feeding on leaves, which can lead to reduced yield and quality. They are particularly destructive during their larval stage, where they can consume large amounts of foliage.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Application of chemical insecticides to control armyworm populations.",
        timing_hint: "Apply when larvae are first detected."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Encouraging natural predators such as birds and beneficial insects to reduce armyworm populations.",
        timing_hint: "Throughout the growing season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotating crops to disrupt the life cycle of armyworms.",
        timing_hint: "Before planting new crops."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Sorghum", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Rice", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cotton", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Fall Armyworm
      pest = TempPest.find_or_initialize_by(name: "Fall Armyworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Spodoptera frugiperda",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "The Fall Armyworm causes significant damage to crops by feeding on leaves, stems, and ears, leading to reduced yield and quality. It is particularly harmful to corn, sorghum, rice, cotton, and soybeans.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Application of chemical insecticides to control Fall Armyworm populations.",
        timing_hint: "Apply when larvae are first detected."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Utilizing natural predators such as parasitic wasps to reduce pest populations.",
        timing_hint: "Encourage natural predators throughout the growing season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotating crops to disrupt the life cycle of the Fall Armyworm.",
        timing_hint: "Implement before planting new crops."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Sorghum", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Rice", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cotton", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Corn Earworm
      pest = TempPest.find_or_initialize_by(name: "Corn Earworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Helicoverpa zea",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "The Corn Earworm primarily damages the ears of corn, feeding on the kernels and causing significant yield loss. It also affects cotton bolls, soybean pods, and tomato fruits, leading to reduced quality and marketability.",
        occurrence_season: "Summer to early fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 1200,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides targeting the larval stage to control populations effectively.",
        timing_hint: "Apply during early larval stages for best results."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as parasitic wasps to help control corn earworm populations.",
        timing_hint: "Release during the growing season when pest populations are high."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the corn earworm.",
        timing_hint: "Implement annually to reduce pest pressure."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cotton", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Tomato Hornworm
      pest = TempPest.find_or_initialize_by(name: "Tomato Hornworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Manduca quinquemaculata",
        family: "Sphingidae",
        order: "Lepidoptera",
        description: "The Tomato Hornworm primarily feeds on the leaves of tomato and bell pepper plants, causing significant defoliation. The larvae are large, green caterpillars that can blend in with the foliage, making them difficult to spot. Heavy infestations can lead to reduced yields and plant stress.",
        occurrence_season: "Spring to Summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Sprays",
        description: "Use insecticidal sprays that are effective against caterpillars to control Tomato Hornworm populations.",
        timing_hint: "Apply when larvae are small and actively feeding."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as parasitic wasps that target Tomato Hornworm larvae.",
        timing_hint: "Release during the early stages of infestation."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the Tomato Hornworm.",
        timing_hint: "Implement at the end of the growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Bell Peppers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Squash Bug
      pest = TempPest.find_or_initialize_by(name: "Squash Bug", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Anasa tristis",
        family: "Coreidae",
        order: "Hemiptera",
        description: "The Squash Bug feeds on the sap of cucumbers and tomatoes, causing wilting, yellowing of leaves, and stunted growth. Infestations can lead to reduced yields and plant death.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 600,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Soap",
        description: "Apply insecticidal soap to affected plants to control Squash Bug populations.",
        timing_hint: "Apply when bugs are first noticed."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as ladybugs to help control Squash Bug populations.",
        timing_hint: "Release beneficial insects early in the season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops each season to disrupt the life cycle of Squash Bugs.",
        timing_hint: "Plan crop rotation before planting."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Cucumbers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Stink Bug
      pest = TempPest.find_or_initialize_by(name: "Stink Bug", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Halyomorpha halys",
        family: "Pentatomidae",
        order: "Hemiptera",
        description: "Stink bugs cause damage to tomatoes and soybeans by piercing the plant tissues and feeding on the sap, leading to wilting, discoloration, and reduced yield.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to control stink bug populations effectively.",
        timing_hint: "Apply during early infestation stages."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Encourage natural predators such as parasitic wasps to help control stink bug populations.",
        timing_hint: "Introduce predators early in the season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of stink bugs.",
        timing_hint: "Implement at the end of the growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Wireworm
      pest = TempPest.find_or_initialize_by(name: "Wireworm", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Agriotes spp.",
        family: "Elateridae",
        order: "Coleoptera",
        description: "Wireworms are the larvae of click beetles and can cause significant damage to the roots and tubers of crops such as potatoes and carrots. They create tunnels in the soil and feed on the plant roots, leading to stunted growth and reduced yields.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to the soil to target wireworm larvae.",
        timing_hint: "Apply before planting or during early crop development."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Nematodes",
        description: "Introduce beneficial nematodes that prey on wireworm larvae.",
        timing_hint: "Apply during the larval stage of wireworms."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of wireworms.",
        timing_hint: "Implement annually to reduce wireworm populations."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Potatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Carrots", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Flea Beetle
      pest = TempPest.find_or_initialize_by(name: "Flea Beetle", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Phyllotreta spp.",
        family: "Chrysomelidae",
        order: "Coleoptera",
        description: "Flea beetles cause small, round holes in the leaves of affected crops, leading to reduced plant vigor and yield. They are particularly damaging to young plants.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Sprays",
        description: "Use insecticidal sprays to control flea beetle populations.",
        timing_hint: "Apply when beetles are first observed."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of flea beetles.",
        timing_hint: "Implement in the following growing season."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as ladybugs to control flea beetle populations.",
        timing_hint: "Release beneficial insects early in the season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Broccoli", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cabbage", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Carrots", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Cabbage Looper
      pest = TempPest.find_or_initialize_by(name: "Cabbage Looper", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Trichoplusia ni",
        family: "Noctuidae",
        order: "Lepidoptera",
        description: "The Cabbage Looper causes significant damage to crops by feeding on the leaves, creating large holes and reducing the overall quality and yield of the plants.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticidal Sprays",
        description: "Use insecticidal sprays to target larvae effectively.",
        timing_hint: "Apply when larvae are first observed."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Beneficial Insects",
        description: "Introduce natural predators such as parasitic wasps.",
        timing_hint: "Release during early infestation."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the pest.",
        timing_hint: "Implement annually."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Broccoli", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cabbage", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Diamondback Moth
      pest = TempPest.find_or_initialize_by(name: "Diamondback Moth", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Plutella xylostella",
        family: "Plutellidae",
        order: "Lepidoptera",
        description: "The Diamondback Moth primarily damages broccoli and cabbage by feeding on the leaves, leading to reduced yield and quality. The larvae create holes in the leaves, which can result in significant crop loss.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 30
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 300,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Apply insecticides to control adult and larval populations.",
        timing_hint: "Apply when larvae are first detected."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Encourage natural predators such as parasitic wasps to control Diamondback Moth populations.",
        timing_hint: "Introduce predators early in the season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotate crops to disrupt the life cycle of the pest.",
        timing_hint: "Implement rotation annually."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Broccoli", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cabbage", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Corn Borer
      pest = TempPest.find_or_initialize_by(name: "Corn Borer", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Ostrinia nubilalis",
        family: "Crambidae",
        order: "Lepidoptera",
        description: "The Corn Borer primarily damages corn and sorghum by boring into the stalks and ears, leading to reduced yield and increased susceptibility to disease.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Insecticides",
        description: "Application of insecticides to control adult and larval populations.",
        timing_hint: "Apply during early stages of crop development."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Natural Predators",
        description: "Encouraging natural predators such as parasitic wasps to control Corn Borer populations.",
        timing_hint: "Throughout the growing season."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop Rotation",
        description: "Rotating crops to disrupt the life cycle of the Corn Borer.",
        timing_hint: "Implement before planting season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Corn", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Sorghum", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Soybean Cyst Nematode
      pest = TempPest.find_or_initialize_by(name: "Soybean Cyst Nematode", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Heterodera glycines",
        family: "Heteroderidae",
        order: "Tylenchida",
        description: "The Soybean Cyst Nematode causes significant damage to soybean plants by feeding on the roots, leading to stunted growth, yellowing leaves, and reduced yield. Infested plants may exhibit symptoms such as wilting and poor pod development.",
        occurrence_season: "Spring to early summer"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Nematicides",
        description: "Chemical treatments that target nematodes in the soil.",
        timing_hint: "Apply before planting or during early growth stages."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Nematode-resistant soybean varieties",
        description: "Planting soybean varieties that are resistant to Soybean Cyst Nematode.",
        timing_hint: "Use resistant varieties in infested fields."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop rotation",
        description: "Rotating soybeans with non-host crops to reduce nematode populations.",
        timing_hint: "Implement rotation every few years."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Soybeans", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

      # Root Knot Nematode
      pest = TempPest.find_or_initialize_by(name: "Root Knot Nematode", is_reference: true, region: 'us')
      pest.assign_attributes(
        user_id: nil,
        name_scientific: "Meloidogyne spp.",
        family: "Heteroderidae",
        order: "Tylenchida",
        description: "Root Knot Nematodes cause galls or knots on the roots of affected plants, leading to stunted growth, yellowing leaves, and reduced yields. In tomatoes and cucumbers, these nematodes can severely impact plant health and productivity.",
        occurrence_season: "Spring to Fall"
      )
      pest.save!

      # Temperature Profile
      if pest.pest_temperature_profile.nil?
        pest.create_pest_temperature_profile!(
          base_temperature: 10,
          max_temperature: 35
        )
      end

      # Thermal Requirement
      if pest.pest_thermal_requirement.nil?
        pest.create_pest_thermal_requirement!(
          required_gdd: 800,
          first_generation_gdd: nil
        )
      end

      # Control Methods
      pest.pest_control_methods.destroy_all
      pest.pest_control_methods.create!(
        method_type: "chemical",
        method_name: "Nematicides",
        description: "Chemical treatments that target nematodes in the soil.",
        timing_hint: "Apply before planting or during early growth stages."
      )
      pest.pest_control_methods.create!(
        method_type: "biological",
        method_name: "Nematode-resistant varieties",
        description: "Planting varieties that are resistant to root knot nematodes.",
        timing_hint: "Select resistant varieties before planting."
      )
      pest.pest_control_methods.create!(
        method_type: "cultural",
        method_name: "Crop rotation",
        description: "Rotating crops to disrupt the life cycle of nematodes.",
        timing_hint: "Implement rotation every growing season."
      )

      # Affected Crops
      crop = TempCrop.find_by(name: "Tomatoes", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end
      crop = TempCrop.find_by(name: "Cucumbers", is_reference: true, region: 'us')
      if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)
        TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)
      end

  end
end
