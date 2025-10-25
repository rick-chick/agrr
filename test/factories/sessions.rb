FactoryBot.define do
  factory :session do
    session_id { Session.generate_session_id }
    expires_at { 2.weeks.from_now }
    
    association :user

    trait :expired do
      expires_at { 1.day.ago }
    end

    trait :expiring_soon do
      expires_at { 1.hour.from_now }
    end

    trait :long_lived do
      expires_at { 1.month.from_now }
    end
  end
end

