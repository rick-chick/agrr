# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Normalizers
      class EntryScheduleWeatherPayloadNormalizerTest < DomainLibTestCase
        setup do
          @rows = (1..3).map do |d|
            {
              "time" => "2026-05-#{d.to_s.rjust(2, '0')}",
              "temperature_2m_min" => 8.0,
              "temperature_2m_max" => 22.0,
              "temperature_2m_mean" => 15.0
            }
          end
        end

        test "flattens nested data.data shape" do
          nested = {
            "data" => {
              "data" => @rows,
              "latitude" => 35.5,
              "longitude" => 139.7
            },
            "prediction_end_date" => "2026-12-31"
          }

          out = EntryScheduleWeatherPayloadNormalizer.call(nested)

          assert out["data"].is_a?(Array)
          assert_equal 3, out["data"].size
          assert_in_delta 35.5, out["latitude"].to_f, 0.001
          assert_in_delta 139.7, out["longitude"].to_f, 0.001
        end

        test "leaves flat payload unchanged" do
          flat = {
            "latitude" => 35.0,
            "longitude" => 139.0,
            "data" => @rows
          }
          out = EntryScheduleWeatherPayloadNormalizer.call(flat)

          assert_equal 3, out["data"].size
          assert_in_delta 35.0, out["latitude"].to_f, 0.001
        end
      end
    end
  end
end
