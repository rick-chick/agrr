# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class FieldCultivationClimatePreconditionsPolicyTest < DomainLibTestCase
        test "missing_weather_location when not present" do
          assert FieldCultivationClimatePreconditionsPolicy.missing_weather_location?(weather_location_present: false)
          refute FieldCultivationClimatePreconditionsPolicy.missing_weather_location?(weather_location_present: true)
        end

        test "missing_cultivation_period when dates absent" do
          assert FieldCultivationClimatePreconditionsPolicy.missing_cultivation_period?(
            start_date: nil,
            completion_date: Date.new(2024, 6, 1)
          )
          refute FieldCultivationClimatePreconditionsPolicy.missing_cultivation_period?(
            start_date: Date.new(2024, 1, 1),
            completion_date: Date.new(2024, 6, 1)
          )
        end
      end
    end
  end
end
