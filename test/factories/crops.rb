FactoryBot.define do
  factory :crop do
    sequence(:name) { |n| "Test Crop #{n}" }
    variety { "general" }
    is_reference { false }
    area_per_unit { 0.25 }  # 0.25㎡
    revenue_per_area { 5000.0 }  # 5000円/㎡
    groups { [] }
    
    association :user

    trait :reference do
      is_reference { true }
      user { nil }
    end

    trait :tomato do
      name { "トマト" }
      variety { "桃太郎" }
      area_per_unit { 0.5 }
      revenue_per_area { 8000.0 }
      groups { ["果菜類", "ナス科"] }
    end

    trait :lettuce do
      name { "レタス" }
      variety { "玉レタス" }
      area_per_unit { 0.2 }
      revenue_per_area { 6000.0 }
      groups { ["葉菜類", "キク科"] }
    end

    trait :carrot do
      name { "ニンジン" }
      variety { "五寸人参" }
      area_per_unit { 0.15 }
      revenue_per_area { 4000.0 }
      groups { ["根菜類", "セリ科"] }
    end

    trait :with_stages do
      after(:create) do |crop|
        create(:crop_stage, :germination, crop: crop, order: 1)
        create(:crop_stage, :vegetative, crop: crop, order: 2)
        create(:crop_stage, :flowering, crop: crop, order: 3)
        create(:crop_stage, :fruiting, crop: crop, order: 4)
      end
    end
  end
end

