# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class FieldCultivationClimateFallbackHorizonPolicyTest < DomainLibTestCase
        test "prediction_days from completion and training end" do
          days = FieldCultivationClimateFallbackHorizonPolicy.prediction_days(
            completion_date: Date.new(2026, 6, 1),
            training_end_date: Date.new(2026, 2, 27)
          )
          assert days.positive?
        end

        test "use_prediction_branch when days positive" do
          assert FieldCultivationClimateFallbackHorizonPolicy.use_prediction_branch?(prediction_days: 10)
          assert_not FieldCultivationClimateFallbackHorizonPolicy.use_prediction_branch?(prediction_days: 0)
        end
      end
    end
  end
end
