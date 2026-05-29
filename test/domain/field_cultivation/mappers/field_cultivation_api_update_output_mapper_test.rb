# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationApiUpdateOutputMapperTest < DomainLibTestCase
        def sample_snapshot(cultivation_days: 90)
          Dtos::FieldCultivationApiUpdateOutputSnapshot.new(
            field_cultivation_id: 7,
            start_date: Date.new(2026, 5, 1),
            completion_date: Date.new(2026, 7, 30),
            cultivation_days: cultivation_days
          )
        end

        test "from_snapshot maps schedule fields to FieldCultivationApiUpdateOutput" do
          snapshot = sample_snapshot

          dto = FieldCultivationApiUpdateOutputMapper.from_snapshot(snapshot)

          assert_instance_of Dtos::FieldCultivationApiUpdateOutput, dto
          assert_equal 7, dto.field_cultivation_id
          assert_equal Date.new(2026, 5, 1), dto.start_date
          assert_equal Date.new(2026, 7, 30), dto.completion_date
          assert_equal 90, dto.cultivation_days
          assert_nil dto.message
          refute dto.public_plan_response?
        end

        test "from_snapshot preserves nil cultivation_days" do
          snapshot = sample_snapshot(cultivation_days: nil)

          dto = FieldCultivationApiUpdateOutputMapper.from_snapshot(snapshot)

          assert_nil dto.cultivation_days
        end
      end
    end
  end
end
