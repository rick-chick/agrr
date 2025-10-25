FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name) { |n| "Test User #{n}" }
    sequence(:google_id) { |n| "google_#{n}_#{SecureRandom.hex(4)}" }
    avatar_url { "dev-avatar.svg" }
    is_anonymous { false }
    admin { false }

    trait :admin do
      admin { true }
    end

    trait :anonymous do
      email { nil }
      name { nil }
      google_id { nil }
      is_anonymous { true }
      admin { false }
    end

    trait :with_avatar_url do
      avatar_url { "https://example.com/avatar.jpg" }
    end
  end
end

