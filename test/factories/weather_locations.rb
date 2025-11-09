# frozen_string_literal: true

FactoryBot.define do
  factory :weather_location do
    sequence(:latitude) { |n| 35.0 + (n % 10) * 0.1 }
    sequence(:longitude) { |n| 139.0 + (n % 10) * 0.1 }
    timezone { "Asia/Tokyo" }
    elevation { 10.0 }
    predicted_weather_data { nil }
  end
end

