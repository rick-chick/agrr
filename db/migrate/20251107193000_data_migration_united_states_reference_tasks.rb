# frozen_string_literal: true

class DataMigrationUnitedStatesReferenceTasks < ActiveRecord::Migration[8.0]
  class TempAgriculturalTask < ActiveRecord::Base
    self.table_name = 'agricultural_tasks'
    has_many :agricultural_task_crops, class_name: 'DataMigrationUnitedStatesReferenceTasks::TempAgriculturalTaskCrop', foreign_key: 'agricultural_task_id'
  end

  class TempAgriculturalTaskCrop < ActiveRecord::Base
    self.table_name = 'agricultural_task_crops'
    belongs_to :agricultural_task, class_name: 'DataMigrationUnitedStatesReferenceTasks::TempAgriculturalTask', foreign_key: 'agricultural_task_id'
    belongs_to :crop, class_name: 'DataMigrationUnitedStatesReferenceTasks::TempCrop', foreign_key: 'crop_id'
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  ALL_CROPS = [
    'Almonds (Nonpareil)',
    'Apples (Red Delicious)',
    'Barley',
    'Bell Peppers',
    'Blueberries',
    'Broccoli',
    'Cabbage',
    'Carrots (Standard)',
    'Corn',
    'Cotton (Upland Cotton)',
    'Cucumbers',
    'Grapes',
    'Lettuce',
    'Oats',
    'Onions',
    'Oranges',
    'Peanuts',
    'Pistachios',
    'Potatoes',
    'Rice (Long Grain)',
    'Rye',
    'Sorghum',
    'Soybeans (Standard)',
    'Strawberries',
    'Sugar Beets',
    'Sugarcane',
    'Tomatoes',
    'Walnuts',
    'Watermelon',
    'Wheat (Winter Wheat)'
  ].freeze

  DIRECT_SEEDING_CROPS = [
    'Barley',
    'Carrots (Standard)',
    'Corn',
    'Cotton (Upland Cotton)',
    'Cucumbers',
    'Lettuce',
    'Oats',
    'Peanuts',
    'Rice (Long Grain)',
    'Rye',
    'Sorghum',
    'Soybeans (Standard)',
    'Sugar Beets',
    'Watermelon',
    'Wheat (Winter Wheat)'
  ].freeze

  TRANSPLANT_CROPS = [
    'Almonds (Nonpareil)',
    'Apples (Red Delicious)',
    'Bell Peppers',
    'Blueberries',
    'Broccoli',
    'Cabbage',
    'Cucumbers',
    'Grapes',
    'Lettuce',
    'Onions',
    'Oranges',
    'Pistachios',
    'Strawberries',
    'Tomatoes',
    'Walnuts'
  ].freeze

  MULCHING_CROPS = [
    'Bell Peppers',
    'Cucumbers',
    'Strawberries',
    'Tomatoes',
    'Watermelon'
  ].freeze

  TUNNEL_CROPS = [
    'Bell Peppers',
    'Cucumbers',
    'Lettuce',
    'Strawberries',
    'Tomatoes'
  ].freeze

  SUPPORT_STRUCTURE_CROPS = [
    'Bell Peppers',
    'Cucumbers',
    'Grapes',
    'Tomatoes'
  ].freeze

  NET_CROPS = [
    'Broccoli',
    'Cabbage',
    'Lettuce',
    'Strawberries'
  ].freeze

  THINNING_CROPS = [
    'Carrots (Standard)',
    'Corn',
    'Lettuce',
    'Sugar Beets',
    'Watermelon'
  ].freeze

  PRUNING_CROPS = [
    'Almonds (Nonpareil)',
    'Apples (Red Delicious)',
    'Bell Peppers',
    'Blueberries',
    'Grapes',
    'Oranges',
    'Pistachios',
    'Strawberries',
    'Tomatoes',
    'Walnuts'
  ].freeze

  TRAINING_CROPS = [
    'Bell Peppers',
    'Cucumbers',
    'Grapes',
    'Tomatoes'
  ].freeze

  LEGACY_ENGLISH_NAMES = %w[
    plowing
    base_fertilization
    seeding
    transplanting
    watering
    weeding
    harvesting
    shipping_preparation
    mulching
    tunnel_setup
    support_structure_setup
    net_installation
    thinning
    pruning
    training
    grading
    packaging
  ].freeze

  TASK_DEFINITIONS = {
    'Plowing' => {
      description: 'Tilling soil to make it soft',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: ['Shovel', 'Hoe', 'Tiller'],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    'Base Fertilization' => {
      description: 'Fertilizer mixed into soil before planting',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: ['Shovel', 'Fertilizer'],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'Seeding' => {
      description: 'Sowing seeds',
      time_per_sqm: 0.005,
      weather_dependency: 'medium',
      required_tools: ['Seeds', 'Seeder'],
      skill_level: 'beginner',
      crops: DIRECT_SEEDING_CROPS
    },
    'Transplanting' => {
      description: 'Planting seedlings',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: ['Seedlings', 'Trowel'],
      skill_level: 'beginner',
      crops: TRANSPLANT_CROPS
    },
    'Watering' => {
      description: 'Watering crops',
      time_per_sqm: 0.01,
      weather_dependency: 'high',
      required_tools: ['Hose', 'Sprinkler'],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'Weeding' => {
      description: 'Removing weeds',
      time_per_sqm: 0.03,
      weather_dependency: 'medium',
      required_tools: ['Sickle', 'Weed Fork'],
      skill_level: 'beginner',
      crops: ALL_CROPS
    },
    'Harvesting' => {
      description: 'Harvesting crops',
      time_per_sqm: 0.05,
      weather_dependency: 'medium',
      required_tools: ['Shears', 'Harvest Basket'],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    'Shipping Preparation' => {
      description: 'Preparation work before shipping (washing, sorting, etc.)',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: ['Bucket', 'Sorting Basket', 'Brush'],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    'Mulching' => {
      description: 'Laying mulch sheets',
      time_per_sqm: 0.01,
      weather_dependency: 'medium',
      required_tools: ['Mulch Sheet', 'Mulch Anchor'],
      skill_level: 'intermediate',
      crops: MULCHING_CROPS
    },
    'Tunnel Setup' => {
      description: 'Installing tunnel supports',
      time_per_sqm: 0.02,
      weather_dependency: 'medium',
      required_tools: ['Tunnel Supports', 'Plastic Sheet'],
      skill_level: 'intermediate',
      crops: TUNNEL_CROPS
    },
    'Support Structure Setup' => {
      description: 'Setting up supports for crops',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: ['Stakes', 'Ties'],
      skill_level: 'intermediate',
      crops: SUPPORT_STRUCTURE_CROPS
    },
    'Net Installation' => {
      description: 'Installing pest control nets',
      time_per_sqm: 0.015,
      weather_dependency: 'medium',
      required_tools: ['Pest Net', 'Net Anchor'],
      skill_level: 'intermediate',
      crops: NET_CROPS
    },
    'Thinning' => {
      description: 'Thinning overcrowded seedlings',
      time_per_sqm: 0.01,
      weather_dependency: 'low',
      required_tools: ['Shears'],
      skill_level: 'beginner',
      crops: THINNING_CROPS
    },
    'Pruning' => {
      description: 'Cutting unnecessary branches',
      time_per_sqm: 0.02,
      weather_dependency: 'low',
      required_tools: ['Pruning Shears'],
      skill_level: 'intermediate',
      crops: PRUNING_CROPS
    },
    'Training' => {
      description: 'Training crops on supports',
      time_per_sqm: 0.015,
      weather_dependency: 'low',
      required_tools: ['Ties', 'Stakes'],
      skill_level: 'intermediate',
      crops: TRAINING_CROPS
    },
    'Grading' => {
      description: 'Sorting harvested produce by grade',
      time_per_sqm: 0.05,
      weather_dependency: 'low',
      required_tools: ['Sorting Basket', 'Grade Chart', 'Scale'],
      skill_level: 'intermediate',
      crops: ALL_CROPS
    },
    'Packaging' => {
      description: 'Packing into boxes or bags for shipping',
      time_per_sqm: 0.03,
      weather_dependency: 'low',
      required_tools: ['Boxes', 'Bags', 'Labels'],
      skill_level: 'beginner',
      crops: ALL_CROPS
    }
  }.freeze

  def up
    say "🌱 United States (us) reference tasks seeding..."

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'us', is_reference: true).pluck(:id)
    if legacy_ids.any?
      TempAgriculturalTaskCrop.where(agricultural_task_id: legacy_ids).delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    TASK_DEFINITIONS.each do |name, attributes|
      task = TempAgriculturalTask.find_or_initialize_by(name: name, region: 'us', is_reference: true)
      task.description = attributes[:description]
      task.time_per_sqm = attributes[:time_per_sqm]
      task.weather_dependency = attributes[:weather_dependency]
      task.required_tools = attributes[:required_tools].to_json
      task.skill_level = attributes[:skill_level]
      task.user_id = nil
      task.is_reference = true
      task.region = 'us'
      task.save!

      TempAgriculturalTaskCrop.where(agricultural_task_id: task.id).delete_all

      attributes[:crops].each do |crop_name|
        crop = TempCrop.find_or_create_by!(name: crop_name, region: 'us', is_reference: true) do |new_crop|
          new_crop.user_id = nil
          new_crop.variety ||= 'Standard'
        end

        TempAgriculturalTaskCrop.create!(agricultural_task_id: task.id, crop_id: crop.id)
      end
    end

    say "✅ United States reference tasks inserted"
  end

  def down
    say "🗑️ Removing United States (us) reference tasks..."

    task_ids = TempAgriculturalTask.where(name: TASK_DEFINITIONS.keys, region: 'us', is_reference: true).pluck(:id)
    TempAgriculturalTaskCrop.where(agricultural_task_id: task_ids).delete_all if task_ids.any?
    TempAgriculturalTask.where(id: task_ids).delete_all if task_ids.any?

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'us', is_reference: true).pluck(:id)
    if legacy_ids.any?
      TempAgriculturalTaskCrop.where(agricultural_task_id: legacy_ids).delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    say "✅ United States reference tasks removed"
  end
end


