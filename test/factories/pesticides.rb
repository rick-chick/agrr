# frozen_string_literal: true

FactoryBot.define do
  factory :pesticide do
    association :crop, factory: :crop, strategy: :build
    association :pest, factory: :pest, strategy: :build
    sequence(:pesticide_id) { |n| "pesticide_#{n}" }
    name { "テスト農薬" }
    active_ingredient { "テスト成分" }
    description { "テスト用の農薬説明" }
    is_reference { true }

    trait :acetamiprid do
      pesticide_id { "acetamiprid" }
      name { "アセタミプリド" }
      active_ingredient { "アセタミプリド" }
      description { "浸透性殺虫剤として広く使用される" }
    end

    trait :imidacloprid do
      pesticide_id { "imidacloprid" }
      name { "イミダクロプリド" }
      active_ingredient { "イミダクロプリド" }
      description { "ネオニコチノイド系殺虫剤" }
    end

    trait :with_usage_constraint do
      after(:create) do |pesticide|
        create(:pesticide_usage_constraint, pesticide: pesticide)
      end
    end

    trait :with_application_detail do
      after(:create) do |pesticide|
        create(:pesticide_application_detail, pesticide: pesticide)
      end
    end

    trait :complete do
      with_usage_constraint
      with_application_detail
    end
  end
end

