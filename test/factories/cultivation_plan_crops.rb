FactoryBot.define do
  factory :cultivation_plan_crop do
    association :cultivation_plan
    association :crop

    name { crop.name }
    variety { crop.variety }
    area_per_unit { crop.area_per_unit }
    revenue_per_area { crop.revenue_per_area }
  end
end

