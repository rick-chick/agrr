FactoryBot.define do
  factory :field_cultivation do
    association :cultivation_plan
    association :cultivation_plan_field
    association :cultivation_plan_crop

    area { 120.0 }
    start_date { Date.current }
    completion_date { Date.current + 90 }
    status { 'pending' }
  end
end

