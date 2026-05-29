# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module Pest
    module Mappers
      class PestShowDetailMapperTest < DomainLibTestCase
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

        TemperatureProfileWire = Data.define(
          :base_temperature,
          :max_temperature
        )

        ThermalRequirementWire = Data.define(
          :required_gdd,
          :first_generation_gdd
        )

        ControlMethodWire = Data.define(
          :id,
          :method_type,
          :method_name,
          :description,
          :timing_hint
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
          :created_at,
          :updated_at
        )

        PestShowDetailWire = Data.define(
          :pest,
          :temperature_profile,
          :thermal_requirement,
          :control_methods,
          :crops
        )

        test "from_snapshot builds PestDetailOutput with nested data sorted in domain" do
          now = Time.utc(2026, 1, 1)
          pest_wire = PestWire.new(
            id: 1,
            user_id: 9,
            name: "アブラムシ",
            name_scientific: "Aphidoidea",
            family: "Aphididae",
            order: "Hemiptera",
            description: "説明",
            occurrence_season: "春",
            region: "jp",
            is_reference: false,
            created_at: now,
            updated_at: now
          )
          temperature_wire = TemperatureProfileWire.new(
            base_temperature: 10.0,
            max_temperature: 30.0
          )
          thermal_wire = ThermalRequirementWire.new(
            required_gdd: 100.0,
            first_generation_gdd: 50.0
          )
          control_wires = [
            ControlMethodWire.new(
              id: 2,
              method_type: "chemical",
              method_name: "薬剤B",
              description: "desc B",
              timing_hint: "開花前"
            ),
            ControlMethodWire.new(
              id: 1,
              method_type: "cultural",
              method_name: "薬剤A",
              description: "desc A",
              timing_hint: "播種前"
            )
          ]
          crop_wires = [
            CropWire.new(
              id: 20,
              user_id: 9,
              name: "トマト",
              variety: nil,
              is_reference: false,
              area_per_unit: 1.0,
              revenue_per_area: 2.0,
              region: "jp",
              created_at: now,
              updated_at: now
            ),
            CropWire.new(
              id: 10,
              user_id: 9,
              name: "ナス",
              variety: "千両",
              is_reference: false,
              area_per_unit: 1.5,
              revenue_per_area: 3.0,
              region: "jp",
              created_at: now,
              updated_at: now
            )
          ]
          wire = PestShowDetailWire.new(
            pest: pest_wire,
            temperature_profile: temperature_wire,
            thermal_requirement: thermal_wire,
            control_methods: control_wires,
            crops: crop_wires
          )

          dto = PestShowDetailMapper.from_snapshot(wire)

          assert_instance_of Dtos::PestDetailOutput, dto
          assert_equal 1, dto.pest.id
          assert_equal "アブラムシ", dto.pest.name
          assert_equal 10.0, dto.temperature_profile.base_temperature
          assert_equal 100.0, dto.thermal_requirement.required_gdd
          assert_equal 2, dto.control_methods.size
          assert_equal "薬剤A", dto.control_methods.first.method_name
          assert_equal "薬剤B", dto.control_methods.last.method_name
          assert_equal 2, dto.associated_crops.size
          assert_equal "トマト", dto.associated_crops.first.name
          assert_equal "ナス", dto.associated_crops.last.name
        end

        test "from_snapshot omits optional profiles when wire fields are nil" do
          now = Time.utc(2026, 1, 1)
          pest_wire = PestWire.new(
            id: 1,
            user_id: nil,
            name: "害虫",
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            region: nil,
            is_reference: true,
            created_at: now,
            updated_at: now
          )
          wire = PestShowDetailWire.new(
            pest: pest_wire,
            temperature_profile: nil,
            thermal_requirement: nil,
            control_methods: [],
            crops: []
          )

          dto = PestShowDetailMapper.from_snapshot(wire)

          assert_nil dto.temperature_profile
          assert_nil dto.thermal_requirement
          assert_empty dto.control_methods
          assert_empty dto.associated_crops
        end
      end
    end
  end
end
