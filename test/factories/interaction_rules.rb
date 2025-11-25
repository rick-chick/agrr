# frozen_string_literal: true

FactoryBot.define do
  factory :interaction_rule do
    rule_type { "continuous_cultivation" }
    source_group { "ナス科" }
    target_group { "ナス科" }
    impact_ratio { 0.7 }
    is_directional { true }
    description { "連作障害により収量が30%減少" }
    is_reference { false }
    
    association :user

    trait :reference do
      is_reference { true }
      user { nil }
    end

    trait :user_owned do
      is_reference { false }
      association :user
    end

    trait :bidirectional do
      is_directional { false }
    end
  end
end
