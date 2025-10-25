FactoryBot.define do
  factory :sunshine_requirement do
    minimum_sunshine_hours { 4.0 }
    target_sunshine_hours { 8.0 }
    
    association :crop_stage

    trait :low_light do
      minimum_sunshine_hours { 2.0 }
      target_sunshine_hours { 5.0 }
    end

    trait :high_light do
      minimum_sunshine_hours { 6.0 }
      target_sunshine_hours { 10.0 }
    end

    trait :shade_tolerant do
      minimum_sunshine_hours { 1.0 }
      target_sunshine_hours { 3.0 }
    end

    trait :full_sun do
      minimum_sunshine_hours { 8.0 }
      target_sunshine_hours { 12.0 }
    end
  end
end

