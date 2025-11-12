# frozen_string_literal: true

FactoryBot.define do
  factory :crop_task_schedule_blueprint do
    association :crop
    association :agricultural_task

    stage_order { 1 }
    stage_name { "定植期" }
    task_type { TaskScheduleItem::FIELD_WORK_TYPE }
    gdd_trigger { BigDecimal("0.0") }
    gdd_tolerance { BigDecimal("10.0") }
    priority { 1 }
    source { "agrr_schedule" }
    description { "土壌準備を行う" }
    weather_dependency { "low" }
    time_per_sqm { BigDecimal("0.1") }

    trait :fertilizer do
      task_type { TaskScheduleItem::BASAL_FERTILIZATION_TYPE }
      source { "agrr_fertilize_plan" }
      description { "基肥を散布する" }
      amount { BigDecimal("3.5") }
      amount_unit { "g/m2" }
    end

    trait :without_agricultural_task do
      agricultural_task { nil }
      sequence(:source_agricultural_task_id) { |n| 10_000 + n }
    end
  end
end
