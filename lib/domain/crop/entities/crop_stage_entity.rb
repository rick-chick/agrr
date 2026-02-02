# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropStageEntity
        attr_reader :id, :crop_id, :name, :order, :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @crop_id = attributes[:crop_id]
          @name = attributes[:name]
          @order = attributes[:order]
          @temperature_requirement = attributes[:temperature_requirement]
          @thermal_requirement = attributes[:thermal_requirement]
          @sunshine_requirement = attributes[:sunshine_requirement]
          @nutrient_requirement = attributes[:nutrient_requirement]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        # ActiveRecordモデルからの変換
        def self.from_model(crop_stage_model)
          new(
            id: crop_stage_model.id,
            crop_id: crop_stage_model.crop_id,
            name: crop_stage_model.name,
            order: crop_stage_model.order,
            temperature_requirement: crop_stage_model.temperature_requirement ? TemperatureRequirementEntity.from_model(crop_stage_model.temperature_requirement) : nil,
            thermal_requirement: crop_stage_model.thermal_requirement ? ThermalRequirementEntity.from_model(crop_stage_model.thermal_requirement) : nil,
            sunshine_requirement: crop_stage_model.sunshine_requirement ? SunshineRequirementEntity.from_model(crop_stage_model.sunshine_requirement) : nil,
            nutrient_requirement: crop_stage_model.nutrient_requirement ? NutrientRequirementEntity.from_model(crop_stage_model.nutrient_requirement) : nil,
            created_at: crop_stage_model.created_at,
            updated_at: crop_stage_model.updated_at
          )
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "Crop ID is required" if crop_id.blank?
          raise ArgumentError, "Order is required" if order.nil?
        end
      end
    end
  end
end


