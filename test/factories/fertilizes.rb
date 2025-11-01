# frozen_string_literal: true

FactoryBot.define do
  factory :fertilize do
    sequence(:name) { |n| "Test Fertilize #{n}" }
    n { 20.0 }
    p { 10.0 }
    k { 10.0 }
    description { "テスト用の肥料" }
    usage { "基肥として使用" }
    application_rate { "1㎡あたり20-50g" }
    is_reference { true }

    trait :urea do
      name { "尿素" }
      n { 46.0 }
      p { nil }
      k { nil }
      description { "窒素肥料として広く使用される" }
      usage { "基肥・追肥に使用可能" }
      application_rate { "1㎡あたり10-30g" }
    end

    trait :phosphate_ammonium do
      name { "リン酸一安" }
      n { 16.0 }
      p { 20.0 }
      k { nil }
      description { "窒素とリン酸を含む肥料" }
      usage { "基肥として使用" }
      application_rate { "1㎡あたり15-40g" }
    end

    trait :potassium_chloride do
      name { "塩化カリ" }
      n { nil }
      p { nil }
      k { 60.0 }
      description { "カリ肥料として使用される" }
      usage { "基肥・追肥に使用可能" }
      application_rate { "1㎡あたり5-15g" }
    end
  end
end

