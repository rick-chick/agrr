FactoryBot.define do
  factory :crop_stage do
    sequence(:name) { |n| "Stage #{n}" }
    sequence(:order) { |n| n }
    
    association :crop

    trait :germination do
      name { "発芽期" }
      order { 1 }
      
      after(:create) do |stage|
        create(:temperature_requirement, :germination, crop_stage: stage)
        create(:thermal_requirement, :germination, crop_stage: stage)
      end
    end

    trait :vegetative do
      name { "栄養成長期" }
      order { 2 }
      
      after(:create) do |stage|
        create(:temperature_requirement, :vegetative, crop_stage: stage)
        create(:thermal_requirement, :vegetative, crop_stage: stage)
      end
    end

    trait :flowering do
      name { "開花期" }
      order { 3 }
      
      after(:create) do |stage|
        create(:temperature_requirement, :flowering, crop_stage: stage)
        create(:thermal_requirement, :flowering, crop_stage: stage)
      end
    end

    trait :fruiting do
      name { "結実期" }
      order { 4 }
      
      after(:create) do |stage|
        create(:temperature_requirement, :fruiting, crop_stage: stage)
        create(:thermal_requirement, :fruiting, crop_stage: stage)
      end
    end
  end
end

