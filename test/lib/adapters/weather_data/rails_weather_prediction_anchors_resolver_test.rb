# frozen_string_literal: true

require "test_helper"

module Adapters
  module WeatherData
    class RailsWeatherPredictionAnchorsResolverTest < ActiveSupport::TestCase
      setup do
        @zone = ActiveSupport::TimeZone["Asia/Tokyo"]
        @resolver = RailsWeatherPredictionAnchorsResolver.new(zone: @zone)
      end

      test "anchors_for matches Rails 20.years minus 2 days from reference midnight in zone" do
        reference = Date.new(2026, 5, 1)
        midnight = @zone.local(reference.year, reference.month, reference.day)
        anchors = @resolver.anchors_for(reference)

        assert_equal (midnight - 20.years).to_date, anchors.training_start_date
        assert_equal (midnight - 2.days).to_date, anchors.training_end_date
        assert_equal Date.new(2026, 1, 1), anchors.current_year_history_start_date
        assert_equal (midnight - 2.days).to_date, anchors.current_year_history_end_date
        assert_equal (midnight + 6.months).to_date, anchors.default_target_end_date
      end
    end
  end
end
