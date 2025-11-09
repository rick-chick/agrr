# frozen_string_literal: true

FactoryBot.define do
  factory :pesticide_usage_constraint do
    association :pesticide
    min_temperature { 5.0 }
    max_temperature { 35.0 }
    max_wind_speed_m_s { 3.0 }
    max_application_count { 3 }
    harvest_interval_days { 1 }
    other_constraints { nil }
  end
end








