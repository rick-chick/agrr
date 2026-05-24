# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Interactors
      class CropStageCopyInteractorTest < DomainLibTestCase
        setup do
          @crop_gateway = mock
          @interactor = CropStageCopyInteractor.new(crop_gateway: @crop_gateway)
        end

        test "creates missing stage and requirements on target crop" do
          ref_temp = Entities::TemperatureRequirementEntity.new(
            id: 1, crop_stage_id: 10, base_temperature: 10.0, optimal_min: 15.0, optimal_max: 25.0,
            low_stress_threshold: 5.0, high_stress_threshold: 30.0, frost_threshold: 0.0,
            sterility_risk_threshold: nil, max_temperature: 35.0
          )
          reference_stage = Entities::CropStageEntity.new(
            id: 10, crop_id: 1, name: "Vegetative", order: 1,
            temperature_requirement: ref_temp,
            thermal_requirement: nil, sunshine_requirement: nil, nutrient_requirement: nil,
            created_at: nil, updated_at: nil
          )
          created_stage = Entities::CropStageEntity.new(
            id: 20, crop_id: 2, name: "Vegetative", order: 1,
            temperature_requirement: nil, thermal_requirement: nil,
            sunshine_requirement: nil, nutrient_requirement: nil,
            created_at: nil, updated_at: nil
          )

          @crop_gateway.expects(:find_by_id).with(1)
          @crop_gateway.expects(:find_by_id).with(2)
          @crop_gateway.expects(:list_by_crop_id).with(1).returns([ reference_stage ])
          @crop_gateway.expects(:list_by_crop_id).with(2).returns([])
          @crop_gateway.expects(:create_crop_stage).returns(created_stage)
          @crop_gateway.expects(:create_temperature_requirement).with(20, instance_of(Dtos::TemperatureRequirementUpdateInput))

          @interactor.call(Dtos::CropStageCopyInput.new(reference_crop_id: 1, new_crop_id: 2))
        end
      end
    end
  end
end
