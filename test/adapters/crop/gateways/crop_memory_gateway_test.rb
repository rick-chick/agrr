# frozen_string_literal: true

require 'test_helper'

module Adapters
  module Crop
    module Gateways
      class CropMemoryGatewayTest < ActiveSupport::TestCase
        def setup
          @gateway = CropMemoryGateway.new
          @crop = create(:crop)
        end

        # CropStage tests
        test 'create_crop_stage creates a new crop stage' do
          dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
            crop_id: @crop.id,
            payload: { name: 'Seedling', order: 1 }
          )

          result = @gateway.create_crop_stage(dto)

          assert_equal 'Seedling', result.name
          assert_equal 1, result.order
          assert_equal @crop.id, result.crop_id
          assert result.id.present?
        end

        test 'create_crop_stage raises error for invalid data' do
          dto = Domain::Crop::Dtos::CropStageCreateInputDto.new(
            crop_id: @crop.id,
            payload: { name: '', order: 1 }
          )

          assert_raises StandardError do
            @gateway.create_crop_stage(dto)
          end
        end

        test 'update_crop_stage updates an existing crop stage' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { name: 'Updated Stage', order: 2 }
          )

          result = @gateway.update_crop_stage(crop_stage.id, dto)

          assert_equal 'Updated Stage', result.name
          assert_equal 2, result.order
        end

        test 'update_crop_stage raises error for non-existent crop stage' do
          dto = Domain::Crop::Dtos::CropStageUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: 99999,
            payload: { name: 'Updated Stage' }
          )

          assert_raises StandardError do
            @gateway.update_crop_stage(99999, dto)
          end
        end

        test 'delete_crop_stage deletes an existing crop stage' do
          crop_stage = create(:crop_stage, crop: @crop)

          @gateway.delete_crop_stage(crop_stage.id)

          assert_raises ActiveRecord::RecordNotFound do
            ::CropStage.find(crop_stage.id)
          end
        end

        test 'delete_crop_stage raises error for non-existent crop stage' do
          assert_raises StandardError do
            @gateway.delete_crop_stage(99999)
          end
        end

        # TemperatureRequirement tests
        test 'find_temperature_requirement returns requirement if exists' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:temperature_requirement, crop_stage: crop_stage)

          result = @gateway.find_temperature_requirement(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.base_temperature, result.base_temperature
        end

        test 'find_temperature_requirement returns nil if not exists' do
          crop_stage = create(:crop_stage, crop: @crop)

          result = @gateway.find_temperature_requirement(crop_stage.id)

          assert_nil result
        end

        test 'create_temperature_requirement creates a new requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { base_temperature: 10.0, optimal_min: 15.0 }
          )

          result = @gateway.create_temperature_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 10.0, result.base_temperature
          assert_equal 15.0, result.optimal_min
        end

        test 'update_temperature_requirement updates existing requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:temperature_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { base_temperature: 12.0, optimal_max: 25.0 }
          )

          result = @gateway.update_temperature_requirement(crop_stage.id, dto)

          assert_equal 12.0, result.base_temperature
          assert_equal 25.0, result.optimal_max
        end

        test 'update_temperature_requirement raises error if requirement not exists' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::TemperatureRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { base_temperature: 12.0 }
          )

          assert_raises StandardError do
            @gateway.update_temperature_requirement(crop_stage.id, dto)
          end
        end

        # ThermalRequirement tests
        test 'find_thermal_requirement returns requirement if exists' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:thermal_requirement, crop_stage: crop_stage)

          result = @gateway.find_thermal_requirement(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.required_gdd, result.required_gdd
        end

        test 'create_thermal_requirement creates a new requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::ThermalRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { required_gdd: 100.0 }
          )

          result = @gateway.create_thermal_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 100.0, result.required_gdd
        end

        test 'update_thermal_requirement updates existing requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:thermal_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::ThermalRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { required_gdd: 150.0 }
          )

          result = @gateway.update_thermal_requirement(crop_stage.id, dto)

          assert_equal 150.0, result.required_gdd
        end

        # SunshineRequirement tests
        test 'find_sunshine_requirement returns requirement if exists' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:sunshine_requirement, crop_stage: crop_stage)

          result = @gateway.find_sunshine_requirement(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.minimum_sunshine_hours, result.minimum_sunshine_hours
        end

        test 'create_sunshine_requirement creates a new requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::SunshineRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { minimum_sunshine_hours: 8.0, target_sunshine_hours: 10.0 }
          )

          result = @gateway.create_sunshine_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 8.0, result.minimum_sunshine_hours
          assert_equal 10.0, result.target_sunshine_hours
        end

        test 'update_sunshine_requirement updates existing requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:sunshine_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::SunshineRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { target_sunshine_hours: 12.0 }
          )

          result = @gateway.update_sunshine_requirement(crop_stage.id, dto)

          assert_equal 12.0, result.target_sunshine_hours
        end

        # NutrientRequirement tests
        test 'find_nutrient_requirement returns requirement if exists' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:nutrient_requirement, crop_stage: crop_stage)

          result = @gateway.find_nutrient_requirement(crop_stage.id)

          assert_equal requirement.id, result.id
          assert_equal requirement.daily_uptake_n, result.daily_uptake_n
        end

        test 'create_nutrient_requirement creates a new requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          dto = Domain::Crop::Dtos::NutrientRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { daily_uptake_n: 1.5, daily_uptake_p: 0.8, region: 'test_region' }
          )

          result = @gateway.create_nutrient_requirement(crop_stage.id, dto)

          assert_equal crop_stage.id, result.crop_stage_id
          assert_equal 1.5, result.daily_uptake_n
          assert_equal 0.8, result.daily_uptake_p
          assert_equal 'test_region', result.region
        end

        test 'update_nutrient_requirement updates existing requirement' do
          crop_stage = create(:crop_stage, crop: @crop)
          requirement = create(:nutrient_requirement, crop_stage: crop_stage)
          dto = Domain::Crop::Dtos::NutrientRequirementUpdateInputDto.new(
            crop_id: @crop.id,
            stage_id: crop_stage.id,
            payload: { daily_uptake_k: 2.0, region: 'updated_region' }
          )

          result = @gateway.update_nutrient_requirement(crop_stage.id, dto)

          assert_equal 2.0, result.daily_uptake_k
          assert_equal 'updated_region', result.region
        end
      end
    end
  end
end