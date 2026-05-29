# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationApiSummaryMapperTest < DomainLibTestCase
        def sample_snapshot(gdd:)
          Dtos::FieldCultivationApiSummarySnapshot.new(
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
          snapshot = sample_snapshot(gdd: 875.25)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(snapshot)

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

        test "from_snapshot preserves gdd when snapshot carries total_gdd" do
          snapshot = sample_snapshot(gdd: 875.25)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(snapshot)

          assert_in_delta 875.25, dto.gdd
        end

        test "from_snapshot preserves nil gdd when snapshot has no total_gdd" do
          snapshot = sample_snapshot(gdd: nil)

          dto = FieldCultivationApiSummaryMapper.from_snapshot(snapshot)

          assert_nil dto.gdd
        end
      end
    end
  end
end
