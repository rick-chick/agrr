# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Calculators
      class EntryScheduleStageGddScalerTest < DomainLibTestCase
        test "scales down stage required_gdd when sum exceeds cap" do
          req = {
            "stage_requirements" => [
              { "thermal" => { "required_gdd" => 800.0 } },
              { "thermal" => { "required_gdd" => 800.0 } }
            ]
          }
          out = EntryScheduleStageGddScaler.call(req, max_total_gdd: 1000.0)
          stages = out["stage_requirements"]
          total = stages.sum { |s| s["thermal"]["required_gdd"].to_f }

          assert_in_delta 1000.0, total, 0.01
          assert_in_delta 500.0, stages[0]["thermal"]["required_gdd"].to_f, 0.01
        end

        test "returns copy unchanged when sum is within cap" do
          req = {
            "stage_requirements" => [
              { "thermal" => { "required_gdd" => 100.0 } }
            ]
          }
          out = EntryScheduleStageGddScaler.call(req, max_total_gdd: 1000.0)

          assert_in_delta 100.0, out["stage_requirements"][0]["thermal"]["required_gdd"].to_f, 0.01
        end
      end
    end
  end
end
