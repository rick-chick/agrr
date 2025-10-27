# frozen_string_literal: true

FactoryBot.define do
  factory :cultivation_plan do
    association :farm
    association :user
    total_area { 1000.0 }
    status { 'pending' }
    plan_type { 'private' }
    plan_year { Date.current.year }
    plan_name { farm&.name || "Test Plan" }
    planning_start_date { Date.new(Date.current.year, 1, 1) }
    planning_end_date { Date.new(Date.current.year + 1, 12, 31) }

    trait :public_plan do
      plan_type { 'public' }
      user { nil }
      plan_year { nil }
      plan_name { nil }
      planning_start_date { Date.current }
      planning_end_date { Date.new(Date.current.year + 1, 12, 31) }
    end

    trait :completed do
      status { 'completed' }
    end

    trait :failed do
      status { 'failed' }
      error_message { 'テストエラー' }
    end
  end
end
