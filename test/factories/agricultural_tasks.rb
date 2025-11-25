# frozen_string_literal: true

FactoryBot.define do
  factory :agricultural_task do
    sequence(:name) { |n| "テストタスク #{n}" }
    description { "テスト用の農業タスク" }
    time_per_sqm { 0.1 }
    weather_dependency { "low" }
    required_tools { ["トラクター"] }
    skill_level { "beginner" }
    is_reference { true }

    trait :soil_preparation do
      name { "土壌準備" }
      description { "畑の土壌を耕し、肥料を混ぜ込む作業" }
      time_per_sqm { 0.1 }
      weather_dependency { "low" }
      required_tools { ["トラクター", "耕運機"] }
      skill_level { "beginner" }
    end

    trait :planting do
      name { "定植" }
      description { "苗を畑に植え付ける作業" }
      time_per_sqm { 0.05 }
      weather_dependency { "medium" }
      required_tools { ["移植ごて"] }
      skill_level { "beginner" }
    end

    trait :reference do
      is_reference { true }
      user { nil }
    end

    trait :user_owned do
      is_reference { false }
      association :user
    end
  end
end

