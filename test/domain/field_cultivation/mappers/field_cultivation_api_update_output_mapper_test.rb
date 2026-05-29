# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationApiUpdateOutputMapperTest < DomainLibTestCase
        Wire = Data.define(
          :field_cultivation_id,
          :start_date,
          :completion_date,
          :cultivation_days
        )

        def sample_wire(cultivation_days: 90)
          Wire.new(
            field_cultivation_id: 7,
            start_date: Date.new(2026, 5, 1),
            completion_date: Date.new(2026, 7, 30),
            cultivation_days: cultivation_days
          )
        end

        test "from_wire maps schedule fields to FieldCultivationApiUpdateOutput" do
          wire = sample_wire

          dto = FieldCultivationApiUpdateOutputMapper.from_wire(wire)

          assert_instance_of Dtos::FieldCultivationApiUpdateOutput, dto
          assert_equal 7, dto.field_cultivation_id
          assert_equal Date.new(2026, 5, 1), dto.start_date
          assert_equal Date.new(2026, 7, 30), dto.completion_date
          assert_equal 90, dto.cultivation_days
          assert_nil dto.message
          refute dto.public_plan_response?
        end

        test "from_wire preserves nil cultivation_days" do
          wire = sample_wire(cultivation_days: nil)

          dto = FieldCultivationApiUpdateOutputMapper.from_wire(wire)

          assert_nil dto.cultivation_days
        end
      end
    end
  end
end
