FactoryBot.define do
  factory :nutrient_requirement do
    daily_uptake_n { 0.5 }
    daily_uptake_p { 0.2 }
    daily_uptake_k { 0.8 }
    
    association :crop_stage

    trait :vegetative_high do
      daily_uptake_n { 1.5 }
      daily_uptake_p { 0.5 }
      daily_uptake_k { 1.8 }
    end

    trait :flowering_high do
      daily_uptake_n { 2.0 }
      daily_uptake_p { 0.8 }
      daily_uptake_k { 2.5 }
    end

    trait :fruiting_high do
      daily_uptake_n { 1.2 }
      daily_uptake_p { 0.4 }
      daily_uptake_k { 1.5 }
    end

    trait :low_intake do
      daily_uptake_n { 0.1 }
      daily_uptake_p { 0.05 }
      daily_uptake_k { 0.2 }
    end
  end
end
