# frozen_string_literal: true

require 'test_helper'

class FetchWeatherDataJobTest < ActiveJob::TestCase
  include AgrrMockHelper

  setup do
    @user = User.new(email: "test@example.com", name: "Test User", google_id: "test", avatar_url: "test.svg", is_anonymous: false, admin: false)
    @user.save(validate: false)
    @anonymous_user = User.anonymous_user
    @start_date = Date.new(2025, 1, 1)
    @end_date = Date.new(2025, 1, 7)
  end

  def create_test_farm(attributes = {})
    @farm = Farm.new({ user: @user, name: "Test Farm", latitude: 35.6762, longitude: 139.6503, weather_data_status: 'fetching', weather_data_fetched_years: 0, weather_data_total_years: 1 }.merge(attributes))
    @farm.save(validate: false)
    @farm
  end

