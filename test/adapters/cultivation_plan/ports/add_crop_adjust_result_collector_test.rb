# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Ports
      class AddCropAdjustResultCollectorTest < ActiveSupport::TestCase
        Failure = Domain::CultivationPlan::Dtos::PlanAllocationAdjustFailure
        Output = Domain::CultivationPlan::Dtos::PlanAllocationAdjustOutput

        test "on_success maps output fields to AddCropAdjustResult" do
          collector = AddCropAdjustResultCollector.new
          collector.on_success(output: Output.new(message: "ok", skipped: false))

          result = collector.add_crop_adjust_result
          assert result.success?
          assert_equal "ok", result.message
        end

        test "on_failure maps failure message and http status from mapper" do
          collector = AddCropAdjustResultCollector.new
          collector.on_failure(
            failure: Failure.new(kind: Failure::KIND_NOT_FOUND, message: "missing")
          )

          result = collector.add_crop_adjust_result
          refute result.success?
          assert_equal "missing", result.message
          assert_equal :not_found, result.http_status
        end
      end
    end
  end
end
