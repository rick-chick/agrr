# frozen_string_literal: true

FactoryBot.define do
  factory :crop_fertilize_profile do
    association :crop
    
    sources { ["inmemory"] }
    notes { "Test fertilizer profile" }

    trait :tomato_profile do
      association :crop, :tomato
      sources { ["JAガイド 2021", "agrr-ai"] }
      notes { "トマトの推奨肥料施用計画" }
    end

    trait :with_applications do
      after(:create) do |profile|
        # 基肥
        create(:crop_fertilize_application, :basal, crop_fertilize_profile: profile)
        # 追肥
        create(:crop_fertilize_application, :topdress, crop_fertilize_profile: profile)
      end
    end
  end
end

