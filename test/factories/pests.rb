# frozen_string_literal: true

FactoryBot.define do
  factory :pest do
    sequence(:pest_id) { |n| "pest_#{n}" }
    name { "テスト害虫" }
    name_scientific { "Test Pest" }
    family { "テスト科" }
    order { "テスト目" }
    description { "テスト用の害虫説明" }
    occurrence_season { "春〜秋" }
    is_reference { true }

    trait :aphid do
      pest_id { "aphid" }
      name { "アブラムシ" }
      name_scientific { "Aphidoidea" }
      family { "アブラムシ科" }
      order { "半翅目" }
      description { "アブラムシは、トマトの葉や茎に集まり、汁を吸うことで植物の成長を妨げます。特に若い葉に被害を与え、葉の変色や萎縮を引き起こします。また、ウイルス病の媒介者としても知られています。" }
      occurrence_season { "春〜秋" }
    end

    trait :spider_mite do
      pest_id { "spider_mite" }
      name { "ダニ" }
      name_scientific { "Tetranychus urticae" }
      family { "ダニ科" }
      order { "クモ目" }
      description { "トマトの葉に小さな白い斑点を作り、葉が黄変し、最終的には枯死することがあります。特に乾燥した環境で発生しやすく、葉の裏側に集まって繁殖します。" }
      occurrence_season { "春〜秋" }
    end

    trait :with_temperature_profile do
      after(:create) do |pest|
        create(:pest_temperature_profile, pest: pest)
      end
    end

    trait :with_thermal_requirement do
      after(:create) do |pest|
        create(:pest_thermal_requirement, pest: pest)
      end
    end

    trait :with_control_methods do
      after(:create) do |pest|
        create(:pest_control_method, :chemical, pest: pest)
        create(:pest_control_method, :biological, pest: pest)
        create(:pest_control_method, :cultural, pest: pest)
      end
    end

    trait :complete do
      with_temperature_profile
      with_thermal_requirement
      with_control_methods
    end
  end
end

