# frozen_string_literal: true

FactoryBot.define do
  factory :crop_fertilize_application do
    association :crop_fertilize_profile
    
    application_type { "basal" }
    count { 1 }
    schedule_hint { "pre-plant" }
    total_n { 6.0 }
    total_p { 2.0 }
    total_k { 3.0 }
    per_application_n { nil }
    per_application_p { nil }
    per_application_k { nil }

    trait :basal do
      application_type { "basal" }
      count { 1 }
      schedule_hint { "pre-plant" }
      total_n { 6.0 }
      total_p { 2.0 }
      total_k { 3.0 }
      per_application_n { nil }
      per_application_p { nil }
      per_application_k { nil }
    end

    trait :topdress do
      application_type { "topdress" }
      count { 2 }
      schedule_hint { "fruiting" }
      total_n { 12.0 }
      total_p { 3.0 }
      total_k { 9.0 }
      per_application_n { 6.0 }
      per_application_p { 1.5 }
      per_application_k { 4.5 }
    end

    trait :topdress_single do
      application_type { "topdress" }
      count { 1 }
      schedule_hint { "fruiting" }
      total_n { 12.0 }
      total_p { 3.0 }
      total_k { 9.0 }
      per_application_n { nil }
      per_application_p { nil }
      per_application_k { nil }
    end
  end
end

