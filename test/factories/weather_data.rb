# frozen_string_literal: true

FactoryBot.define do
  factory :weather_datum do
    association :weather_location
    sequence(:date) { |n| Date.new(2000, 1, 1) + n.days }
    temperature_max { 25.0 }
    temperature_min { 15.0 }
    temperature_mean { 20.0 }
    precipitation { 0.0 }
    sunshine_hours { 6.0 }
    wind_speed { 2.0 }
    weather_code { 0 }
  end
end

