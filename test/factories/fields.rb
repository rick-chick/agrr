FactoryBot.define do
  factory :field do
    sequence(:name) { |n| "Test Field #{n}" }
    area { 1000.0 }  # 1000㎡
    daily_fixed_cost { 500.0 }  # 1日あたり500円
    
    association :farm
    association :user

    trait :small do
      area { 100.0 }
      daily_fixed_cost { 100.0 }
    end

    trait :large do
      area { 5000.0 }
      daily_fixed_cost { 2000.0 }
    end

    trait :no_cost do
      daily_fixed_cost { 0 }
    end

    trait :anonymous do
      user { nil }
    end
  end
end

