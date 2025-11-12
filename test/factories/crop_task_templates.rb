# frozen_string_literal: true

FactoryBot.define do
  factory :crop_task_template do
    association :crop
    sequence(:name) { |n| "作業テンプレート#{n}" }
    description { "作業テンプレートの説明" }
    time_per_sqm { 0.1 }
    weather_dependency { "low" }
    required_tools { ["手袋"] }
    skill_level { "beginner" }
    task_type { "field" }
    is_reference { false }
  end
end

