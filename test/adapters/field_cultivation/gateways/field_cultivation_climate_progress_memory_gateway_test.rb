# frozen_string_literal: true

require "test_helper"

module Adapters
  module FieldCultivation
    module Gateways
      class FieldCultivationClimateProgressMemoryGatewayTest < ActiveSupport::TestCase
        def setup
          logger = Object.new
          logger.define_singleton_method(:info) { |_msg| nil }
          @gateway = FieldCultivationClimateProgressMemoryGateway.new(logger: logger)
          @crop_entity = Domain::Crop::Entities::CropEntity.new(
            id: 1,
            user_id: 1,
            name: "tomato",
            variety: nil,
            is_reference: false
          )
        end

        test "calculate_progress returns mock progress records and total gdd" do
          start_date = Date.new(2026, 1, 1)
          result = @gateway.calculate_progress(
            crop_entity: @crop_entity,
            start_date: start_date,
            weather_payload: { "data" => [] }
          )

          assert_equal 875.0, result["total_gdd"]
          records = result["progress_records"]
          assert records.is_a?(Array)
          assert records.length.positive?
          assert_equal start_date.to_s, records.first["date"]
          assert records.last["cumulative_gdd"].positive?
        end
      end
    end
  end
end
