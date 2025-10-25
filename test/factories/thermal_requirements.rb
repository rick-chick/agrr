FactoryBot.define do
  factory :thermal_requirement do
    required_gdd { 200.0 }
    
    association :crop_stage

    trait :germination do
      required_gdd { 150.0 }
    end

    trait :vegetative do
      required_gdd { 400.0 }
    end

    trait :flowering do
      required_gdd { 300.0 }
    end

    trait :fruiting do
      required_gdd { 250.0 }
    end

    trait :short_season do
      required_gdd { 100.0 }
    end

    trait :long_season do
      required_gdd { 800.0 }
    end
  end
end

