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
          @crop_requirement = { "crop" => { "id" => 1 } }
        end

        test "calculate_progress returns mock progress records and total gdd" do
          start_date = Date.new(2026, 1, 1)
          result = @gateway.calculate_progress(
            crop_requirement: @crop_requirement,
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

        test "mock progress uses translated stage names" do
          I18n.locale = :ja
          start_date = Date.today

          result = @gateway.calculate_progress(
            crop_requirement: @crop_requirement,
            start_date: start_date,
            weather_payload: { "data" => [] }
          )
          records = result["progress_records"]
          translated_stage_names = I18n.t("controllers.field_cultivations.mock_progress.stage_names")

          assert records.present?
          assert (records.map { |r| r["stage_name"] }.uniq - translated_stage_names).empty?
        end
      end
    end
  end
end
