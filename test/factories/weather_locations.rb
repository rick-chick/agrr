# frozen_string_literal: true

FactoryBot.define do
  factory :weather_location do
    latitude { 35.0 + SecureRandom.random_number * 10 }
    longitude { 139.0 + SecureRandom.random_number * 10 }
    timezone { "Asia/Tokyo" }
    elevation { 10.0 }
    predicted_weather_data { nil }
  end
end
