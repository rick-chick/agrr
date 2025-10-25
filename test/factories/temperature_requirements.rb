FactoryBot.define do
  factory :temperature_requirement do
    base_temperature { 10.0 }
    optimal_min { 15.0 }
    optimal_max { 25.0 }
    low_stress_threshold { 5.0 }
    high_stress_threshold { 30.0 }
    frost_threshold { 0.0 }
    max_temperature { 35.0 }
    
    association :crop_stage

    trait :germination do
      base_temperature { 8.0 }
      optimal_min { 15.0 }
      optimal_max { 20.0 }
      low_stress_threshold { 5.0 }
      high_stress_threshold { 25.0 }
      frost_threshold { 0.0 }
      max_temperature { 30.0 }
    end

    trait :vegetative do
      base_temperature { 10.0 }
      optimal_min { 18.0 }
      optimal_max { 25.0 }
      low_stress_threshold { 8.0 }
      high_stress_threshold { 30.0 }
      frost_threshold { 0.0 }
      max_temperature { 35.0 }
    end

    trait :flowering do
      base_temperature { 12.0 }
      optimal_min { 20.0 }
      optimal_max { 28.0 }
      low_stress_threshold { 10.0 }
      high_stress_threshold { 32.0 }
      frost_threshold { 2.0 }
      max_temperature { 38.0 }
    end

    trait :fruiting do
      base_temperature { 10.0 }
      optimal_min { 18.0 }
      optimal_max { 26.0 }
      low_stress_threshold { 8.0 }
      high_stress_threshold { 30.0 }
      frost_threshold { 0.0 }
      max_temperature { 35.0 }
    end

    trait :cold_tolerant do
      base_temperature { 0.0 }
      optimal_min { 10.0 }
      optimal_max { 20.0 }
      low_stress_threshold { -5.0 }
      frost_threshold { -10.0 }
    end

    trait :heat_loving do
      base_temperature { 15.0 }
      optimal_min { 25.0 }
      optimal_max { 35.0 }
      high_stress_threshold { 40.0 }
      max_temperature { 45.0 }
    end
  end
end

