FactoryBot.define do
  factory :farm do
    sequence(:name) { |n| "Test Farm #{n}" }
    sequence(:latitude) { |n| 35.0 + (n % 10) * 0.1 }  # 35.0-36.0の範囲
    sequence(:longitude) { |n| 135.0 + (n % 10) * 0.1 }  # 135.0-136.0の範囲
    is_reference { false }
    weather_data_status { :pending }
    weather_data_fetched_years { 0 }
    weather_data_total_years { 0 }
    
    association :user

    trait :reference do
      is_reference { true }
      association :user, factory: [:user, :anonymous]
    end

    trait :user_owned do
      is_reference { false }
      association :user
    end

  trait :with_field do
    after(:create) do |farm, evaluator|
      # Create a default field associated with this farm and its user to ensure non-zero total area
      create(:field, farm: farm, user: farm.user)
    end
  end

    trait :with_weather_data do
      weather_data_status { :completed }
      weather_data_fetched_years { 25 }
      weather_data_total_years { 25 }
    end

    trait :fetching_weather do
      weather_data_status { :fetching }
      weather_data_fetched_years { 10 }
      weather_data_total_years { 25 }
    end

    trait :weather_failed do
      weather_data_status { :failed }
      weather_data_last_error { "API connection error" }
    end

    # 日本の各地域の座標
    trait :hokkaido do
      latitude { 43.0642 }
      longitude { 141.3469 }
      name { "札幌農場" }
    end

    trait :tohoku do
      latitude { 38.2682 }
      longitude { 140.8694 }
      name { "仙台農場" }
    end

    trait :kanto do
      latitude { 35.6762 }
      longitude { 139.6503 }
      name { "東京農場" }
    end

    trait :kyushu do
      latitude { 33.5904 }
      longitude { 130.4017 }
      name { "福岡農場" }
    end
  end
end

