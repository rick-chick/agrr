# frozen_string_literal: true

FactoryBot.define do
  factory :pest_thermal_requirement do
    association :pest
    required_gdd { 300.0 }
    first_generation_gdd { 100.0 }
  end
end

