# frozen_string_literal: true

FactoryBot.define do
  factory :task_schedule do
    association :cultivation_plan
    field_cultivation { association :field_cultivation, cultivation_plan: cultivation_plan }
    category { 'general' }
    status { TaskSchedule::STATUSES[:active] }
    source { 'agrr' }
    generated_at { Time.zone.now }
  end

  factory :task_schedule_item do
    association :task_schedule
    task_type { TaskScheduleItem::FIELD_WORK_TYPE }
    name { "作業#{SecureRandom.hex(2)}" }
    description { 'テスト作業' }
    stage_name { '初期生育' }
    stage_order { 1 }
    gdd_trigger { BigDecimal('120.0') }
    gdd_tolerance { BigDecimal('10.0') }
    scheduled_date { Date.current }
    priority { 2 }
    source { 'agrr_schedule' }
    weather_dependency { 'no_rain_24h' }
    time_per_sqm { BigDecimal('0.5') }
    status { TaskScheduleItem::STATUSES[:planned] }
  end
end


