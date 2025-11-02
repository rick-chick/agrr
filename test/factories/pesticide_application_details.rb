# frozen_string_literal: true

FactoryBot.define do
  factory :pesticide_application_detail do
    association :pesticide
    dilution_ratio { "1000倍" }
    amount_per_m2 { 0.1 }
    amount_unit { "ml" }
    application_method { "散布" }
  end
end

