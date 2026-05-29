# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationApiSummaryMapperTest < DomainLibTestCase
        Wire = Data.define(
          :id,
          :field_name,
          :crop_name,
          :area,
          :start_date,
          :completion_date,
          :cultivation_days,
          :estimated_cost,
          :gdd,
          :status
        )

        def sample_wire(gdd:)
          Wire.new(
            id: 42,
            field_name: "North plot",
            crop_name: "Tomato",
            area: 120.5,
            start_date: Date.new(2026, 4, 1),
            completion_date: Date.new(2026, 8, 1),
            cultivation_days: 123,
            estimated_cost: 9_999.0,
            gdd: gdd,
            status: "completed"
          )
        end

        test "from_snapshot maps required fields to FieldCultivationApiSummary" do
          wire = sample_wire(gdd: 875.25)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(wire)

          assert_instance_of Dtos::FieldCultivationApiSummary, dto
          assert_equal 42, dto.id
          assert_equal "North plot", dto.field_name
          assert_equal "Tomato", dto.crop_name
          assert_in_delta 120.5, dto.area
          assert_equal Date.new(2026, 4, 1), dto.start_date
          assert_equal Date.new(2026, 8, 1), dto.completion_date
          assert_equal 123, dto.cultivation_days
          assert_in_delta 9_999.0, dto.estimated_cost
          assert_equal "completed", dto.status
        end

        test "from_snapshot preserves gdd when wire carries total_gdd" do
          wire = sample_wire(gdd: 875.25)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(wire)

          assert_in_delta 875.25, dto.gdd
        end

        test "from_snapshot preserves nil gdd when wire has no total_gdd" do
          wire = sample_wire(gdd: nil)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(wire)

          assert_nil dto.gdd
        end
      end
    end
  end
end
