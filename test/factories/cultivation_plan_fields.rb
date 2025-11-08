FactoryBot.define do
  factory :cultivation_plan_field do
    association :cultivation_plan
    sequence(:name) { |n| "圃場#{n}" }
    area { 100.0 }
    daily_fixed_cost { 500.0 }
  end
end

