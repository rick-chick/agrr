# frozen_string_literal: true

FactoryBot.define do
  factory :pest_control_method do
    association :pest
    method_type { "chemical" }
    method_name { "殺虫剤" }
    description { "テスト用の防除方法説明" }
    timing_hint { "発生初期に散布" }

    trait :chemical do
      method_type { "chemical" }
      method_name { "殺虫剤" }
      description { "アブラムシに対して効果的な殺虫剤を使用します。" }
      timing_hint { "発生初期に散布" }
    end

    trait :biological do
      method_type { "biological" }
      method_name { "天敵の放飼" }
      description { "アブラムシを捕食する天敵（例: テントウムシ）を放飼します。" }
      timing_hint { "アブラムシの発生が確認された時" }
    end

    trait :cultural do
      method_type { "cultural" }
      method_name { "作物の輪作" }
      description { "アブラムシの発生を抑えるために、作物の輪作を行います。" }
      timing_hint { "次年度の栽培計画に組み込む" }
    end

    trait :physical do
      method_type { "physical" }
      method_name { "粘着トラップ" }
      description { "黄色の粘着トラップを使用して捕獲します。" }
      timing_hint { "発生時期に設置" }
    end
  end
end








