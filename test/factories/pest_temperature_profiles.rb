# frozen_string_literal: true

FactoryBot.define do
  factory :pest_temperature_profile do
    association :pest
    base_temperature { 10.0 }
    max_temperature { 30.0 }
  end
end

