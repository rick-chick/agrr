# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Crop
    module Mappers
      class CropShowDetailMapperTest < DomainLibTestCase
        TemperatureRequirementWire = Data.define(
          :id,
          :crop_stage_id,
          :base_temperature,
          :optimal_min,
          :optimal_max,
          :low_stress_threshold,
          :high_stress_threshold,
          :frost_threshold,
          :sterility_risk_threshold,
          :max_temperature
        )

        CropStageWire = Data.define(
          :id,
          :crop_id,
          :name,
          :order,
          :created_at,
          :updated_at,
          :temperature_requirement,
          :thermal_requirement,
          :sunshine_requirement,
          :nutrient_requirement
        )

        PestWire = Data.define(
          :id,
          :user_id,
          :name,
          :name_scientific,
          :family,
          :order,
          :description,
          :occurrence_season,
          :region,
          :is_reference,
          :created_at,
          :updated_at
        )

        CropWire = Data.define(
          :id,
          :user_id,
          :name,
          :variety,
          :is_reference,
          :area_per_unit,
          :revenue_per_area,
          :region,
          :groups,
          :created_at,
          :updated_at,
          :crop_stages,
          :pests
        )

        test "from_snapshot builds CropDetailOutput with crop stages and pests" do
          now = Time.utc(2026, 1, 1)
          temp_wire = TemperatureRequirementWire.new(
            id: 10,
            crop_stage_id: 2,
            base_temperature: 10.0,
            optimal_min: 15.0,
            optimal_max: 25.0,
            low_stress_threshold: 12.0,
            high_stress_threshold: 28.0,
            frost_threshold: 0.0,
            sterility_risk_threshold: 32.0,
            max_temperature: 35.0
          )
          stage_wire = CropStageWire.new(
            id: 2,
            crop_id: 1,
            name: "生育期",
            order: 1,
            created_at: now,
            updated_at: now,
            temperature_requirement: temp_wire,
            thermal_requirement: nil,
            sunshine_requirement: nil,
            nutrient_requirement: nil
          )
          pest_wire = PestWire.new(
            id: 3,
            user_id: 9,
            name: "害虫A",
            name_scientific: "Pestus",
            family: "fam",
            order: "ord",
            description: "desc",
            occurrence_season: "summer",
            region: "jp",
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          wire = CropWire.new(
            id: 1,
            user_id: 9,
            name: "トマト",
            variety: "桃太郎",
            is_reference: false,
            area_per_unit: 0.5,
            revenue_per_area: 1000.0,
            region: "jp",
            groups: [ "果菜" ],
            created_at: now,
            updated_at: now,
            crop_stages: [ stage_wire ],
            pests: [ pest_wire ]
          )

          dto = CropShowDetailMapper.from_snapshot(wire)

          assert_instance_of Dtos::CropDetailOutput, dto
          assert_equal 1, dto.crop.id
          assert_equal "トマト", dto.crop.name
          assert_equal "桃太郎", dto.crop.variety
          assert_equal 1, dto.crop.crop_stages.size
          assert_equal "生育期", dto.crop.crop_stages.first.name
          assert_equal 10.0, dto.crop.crop_stages.first.temperature_requirement.base_temperature
          assert_equal 1, dto.crop.associated_pests.size
          assert_equal "害虫A", dto.crop.associated_pests.first.name
        end
      end
    end
  end
end
