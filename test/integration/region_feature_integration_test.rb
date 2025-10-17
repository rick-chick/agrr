# frozen_string_literal: true

require "test_helper"

# Region機能の統合テスト
# 
# 要件：
# R1: 基本データ操作 - 各モデルでregionカラムを持ち、CRUD操作可能
# R2: 地域別フィルタリング - by_regionスコープで地域別データ取得
# R3: 地域別参照データ提供 - is_reference=trueのデータを地域別に提供
# R4: 地域別ビジネスロジック - 同じ名前でも地域で異なるデータ
# R5: データの独立性 - 地域間でデータを独立管理
class RegionFeatureIntegrationTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:one)
    @anonymous_user = User.create!(
      name: "Anonymous User",
      email: "anonymous@integration.test",
      google_id: "anonymous_integration_#{SecureRandom.hex(8)}",
      is_anonymous: true
    )
  end

  # ====================================================================
  # R1: 基本データ操作のテスト
  # ====================================================================

  test "R1: all models should support region column with CRUD operations" do
    # Farm
    farm = Farm.create!(
      name: "Test Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )
    assert_equal "jp", farm.region
    farm.update!(region: "us")
    assert_equal "us", farm.region
    farm.update!(region: nil)
    assert_nil farm.region

    # Field
    field = Field.create!(
      farm: farm,
      user: @user,
      name: "Test Field",
      region: "jp"
    )
    assert_equal "jp", field.region
    field.update!(region: "us")
    assert_equal "us", field.region

    # Crop
    crop = Crop.create!(
      name: "Test Crop",
      user: @user,
      region: "jp"
    )
    assert_equal "jp", crop.region
    crop.update!(region: "us")
    assert_equal "us", crop.region

    # InteractionRule
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "TestGroup",
      target_group: "TestGroup",
      impact_ratio: 0.7,
      region: "jp"
    )
    assert_equal "jp", rule.region
    rule.update!(region: "us")
    assert_equal "us", rule.region
  end

  test "R1: region should be optional and default to nil" do
    farm = Farm.create!(
      name: "Global Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0
    )
    assert_nil farm.region

    field = Field.create!(farm: farm, user: @user, name: "Global Field")
    assert_nil field.region

    crop = Crop.create!(name: "Global Crop", user: @user)
    assert_nil crop.region

    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "GlobalGroup",
      target_group: "GlobalGroup",
      impact_ratio: 0.7
    )
    assert_nil rule.region
  end

  # ====================================================================
  # R2: 地域別フィルタリングのテスト
  # ====================================================================

  test "R2: by_region scope should filter data by region across all models" do
    # 日本のデータを作成
    farm_jp = Farm.create!(name: "JP Farm", user: @user, latitude: 35.0, longitude: 135.0, region: "jp")
    field_jp = Field.create!(farm: farm_jp, user: @user, name: "JP Field", region: "jp")
    crop_jp = Crop.create!(name: "JP Crop", user: @user, region: "jp")
    rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "JPGroup",
      target_group: "JPGroup",
      impact_ratio: 0.7,
      region: "jp"
    )

    # アメリカのデータを作成
    farm_us = Farm.create!(name: "US Farm", user: @user, latitude: 42.0, longitude: -93.0, region: "us")
    field_us = Field.create!(farm: farm_us, user: @user, name: "US Field", region: "us")
    crop_us = Crop.create!(name: "US Crop", user: @user, region: "us")
    rule_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "USGroup",
      target_group: "USGroup",
      impact_ratio: 0.8,
      region: "us"
    )

    # グローバルデータを作成
    farm_global = Farm.create!(name: "Global Farm", user: @user, latitude: 40.0, longitude: 140.0)
    field_global = Field.create!(farm: farm_global, user: @user, name: "Global Field")
    crop_global = Crop.create!(name: "Global Crop", user: @user)
    rule_global = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "GlobalGroup",
      target_group: "GlobalGroup",
      impact_ratio: 0.75
    )

    # 日本のデータのみ取得
    jp_farms = Farm.by_region("jp")
    jp_fields = Field.by_region("jp")
    jp_crops = Crop.by_region("jp")
    jp_rules = InteractionRule.by_region("jp")

    assert_includes jp_farms, farm_jp
    assert_not_includes jp_farms, farm_us
    assert_not_includes jp_farms, farm_global

    assert_includes jp_fields, field_jp
    assert_not_includes jp_fields, field_us
    assert_not_includes jp_fields, field_global

    assert_includes jp_crops, crop_jp
    assert_not_includes jp_crops, crop_us
    assert_not_includes jp_crops, crop_global

    assert_includes jp_rules, rule_jp
    assert_not_includes jp_rules, rule_us
    assert_not_includes jp_rules, rule_global
  end

  test "R2: by_region scope should work with other scopes" do
    # 参照データ
    ref_farm_jp = Farm.create!(
      name: "JP Reference Farm",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )

    ref_crop_jp = Crop.create!(
      name: "JP Reference Crop",
      is_reference: true,
      region: "jp"
    )

    ref_rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "RefGroup",
      target_group: "RefGroup",
      impact_ratio: 0.7,
      is_reference: true,
      region: "jp"
    )

    # ユーザーデータ
    user_farm_jp = Farm.create!(
      name: "JP User Farm",
      user: @user,
      latitude: 36.0,
      longitude: 136.0,
      region: "jp"
    )

    user_crop_jp = Crop.create!(
      name: "JP User Crop",
      user: @user,
      is_reference: false,
      region: "jp"
    )

    # reference + by_region
    assert_equal 1, Farm.reference.by_region("jp").count
    assert_includes Farm.reference.by_region("jp"), ref_farm_jp

    assert_equal 1, Crop.reference.by_region("jp").count
    assert_includes Crop.reference.by_region("jp"), ref_crop_jp

    assert_equal 1, InteractionRule.reference.by_region("jp").count
    assert_includes InteractionRule.reference.by_region("jp"), ref_rule_jp

    # user_owned + by_user + by_region
    assert_equal 1, Farm.user_owned.by_user(@user).by_region("jp").count
    assert_includes Farm.user_owned.by_user(@user).by_region("jp"), user_farm_jp

    assert_equal 1, Crop.user_owned.by_region("jp").count
    assert_includes Crop.user_owned.by_region("jp"), user_crop_jp
  end

  # ====================================================================
  # R3: 地域別参照データ提供のテスト
  # ====================================================================

  test "R3: should provide region-specific reference data for Japanese users" do
    # 日本の参照データセットを作成
    jp_farm = Farm.create!(
      name: "東京サンプル農場",
      user: @anonymous_user,
      latitude: 35.6762,
      longitude: 139.6503,
      is_reference: true,
      region: "jp"
    )

    jp_crops = [
      Crop.create!(
        name: "コシヒカリ",
        variety: "水稲",
        is_reference: true,
        region: "jp",
        area_per_unit: 0.25,
        revenue_per_area: 5000,
        groups: ["イネ科", "主食"]
      ),
      Crop.create!(
        name: "大豆",
        variety: "エンレイ",
        is_reference: true,
        region: "jp",
        area_per_unit: 0.3,
        revenue_per_area: 3000,
        groups: ["マメ科"]
      )
    ]

    jp_rules = [
      InteractionRule.create!(
        rule_type: "continuous_cultivation",
        source_group: "イネ科",
        target_group: "イネ科",
        impact_ratio: 0.8,
        description: "水稲の連作によるやや減収",
        is_reference: true,
        region: "jp"
      ),
      InteractionRule.create!(
        rule_type: "continuous_cultivation",
        source_group: "マメ科",
        target_group: "イネ科",
        impact_ratio: 1.1,
        description: "マメ科後のイネ科は増収効果",
        is_reference: true,
        is_directional: true,
        region: "jp"
      )
    ]

    # 日本のユーザーが取得すべきデータ
    japanese_farms = Farm.reference.by_region("jp")
    japanese_crops = Crop.reference.by_region("jp")
    japanese_rules = InteractionRule.reference.by_region("jp")

    # 検証
    assert_equal 1, japanese_farms.count
    assert_includes japanese_farms, jp_farm

    assert_equal 2, japanese_crops.count
    japanese_crops.each do |crop|
      assert_equal "jp", crop.region
      assert crop.is_reference
    end

    assert_equal 2, japanese_rules.count
    japanese_rules.each do |rule|
      assert_equal "jp", rule.region
      assert rule.is_reference
    end
  end

  test "R3: should provide region-specific reference data for American users" do
    # アメリカの参照データセットを作成
    us_farm = Farm.create!(
      name: "Iowa Corn Belt Farm",
      user: @anonymous_user,
      latitude: 42.0308,
      longitude: -93.6319,
      is_reference: true,
      region: "us"
    )

    us_crops = [
      Crop.create!(
        name: "Corn",
        variety: "Field Corn",
        is_reference: true,
        region: "us",
        area_per_unit: 1.0,
        revenue_per_area: 8000,
        groups: ["Poaceae"]
      ),
      Crop.create!(
        name: "Soybean",
        variety: "Glycine max",
        is_reference: true,
        region: "us",
        area_per_unit: 1.0,
        revenue_per_area: 6000,
        groups: ["Fabaceae"]
      )
    ]

    us_rules = [
      InteractionRule.create!(
        rule_type: "continuous_cultivation",
        source_group: "Poaceae",
        target_group: "Poaceae",
        impact_ratio: 0.7,
        description: "Continuous corn reduces yield",
        is_reference: true,
        region: "us"
      ),
      InteractionRule.create!(
        rule_type: "continuous_cultivation",
        source_group: "Fabaceae",
        target_group: "Poaceae",
        impact_ratio: 1.15,
        description: "Corn after soybean yield boost",
        is_reference: true,
        is_directional: true,
        region: "us"
      )
    ]

    # アメリカのユーザーが取得すべきデータ
    american_farms = Farm.reference.by_region("us")
    american_crops = Crop.reference.by_region("us")
    american_rules = InteractionRule.reference.by_region("us")

    # 検証
    assert_equal 1, american_farms.count
    assert_includes american_farms, us_farm

    assert_equal 2, american_crops.count
    american_crops.each do |crop|
      assert_equal "us", crop.region
      assert crop.is_reference
    end

    assert_equal 2, american_rules.count
    american_rules.each do |rule|
      assert_equal "us", rule.region
      assert rule.is_reference
    end
  end

  test "R3: reference farms should belong to anonymous user" do
    farm = Farm.create!(
      name: "Reference Farm",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )

    assert farm.valid?
    assert farm.is_reference
    assert farm.user.anonymous?
  end

  test "R3: reference farm should not belong to regular user" do
    farm = Farm.new(
      name: "Invalid Reference Farm",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )

    assert_not farm.valid?
    assert_includes farm.errors[:is_reference], "参照農場はアノニマスユーザーにのみ設定できます"
  end

  # ====================================================================
  # R4: 地域別ビジネスロジックのテスト
  # ====================================================================

  test "R4: same crop name can have different varieties and revenue by region" do
    # 日本の米
    rice_jp = Crop.create!(
      name: "Rice",
      variety: "Koshihikari (Japonica)",
      is_reference: true,
      region: "jp",
      area_per_unit: 0.25,
      revenue_per_area: 5000,
      groups: ["イネ科"]
    )

    # アメリカの米
    rice_us = Crop.create!(
      name: "Rice",
      variety: "Long Grain",
      is_reference: true,
      region: "us",
      area_per_unit: 1.0,
      revenue_per_area: 7000,
      groups: ["Poaceae"]
    )

    # 同じ名前でも異なる品種・収益
    assert_equal "Rice", rice_jp.name
    assert_equal "Rice", rice_us.name
    assert_not_equal rice_jp.variety, rice_us.variety
    assert_not_equal rice_jp.revenue_per_area, rice_us.revenue_per_area
    assert_not_equal rice_jp.groups, rice_us.groups
  end

  test "R4: same crop group can have different impact ratios by region" do
    # 日本のナス科連作ペナルティ（高湿度環境で病害リスク大）
    rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.6,  # 40%減収
      description: "日本の高湿度環境では病害リスク大",
      is_reference: true,
      region: "jp"
    )

    # アメリカのナス科連作ペナルティ（比較的軽微）
    rule_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.8,  # 20%減収
      description: "Moderate continuous cropping penalty",
      is_reference: true,
      region: "us"
    )

    # 同じ作物グループでも地域によって影響度が異なる
    assert_equal "Solanaceae", rule_jp.source_group
    assert_equal "Solanaceae", rule_us.source_group
    assert rule_jp.impact_ratio < rule_us.impact_ratio
    
    # それぞれの地域でのみ取得される
    jp_solanaceae_rules = InteractionRule.reference.by_region("jp").where(source_group: "Solanaceae")
    us_solanaceae_rules = InteractionRule.reference.by_region("us").where(source_group: "Solanaceae")
    
    assert_equal 1, jp_solanaceae_rules.count
    assert_equal 0.6, jp_solanaceae_rules.first.impact_ratio
    
    assert_equal 1, us_solanaceae_rules.count
    assert_equal 0.8, us_solanaceae_rules.first.impact_ratio
  end

  test "R4: reference farms should be ordered by latitude descending within region" do
    # 日本の農場を緯度順に作成
    kyushu = Farm.create!(
      name: "九州農場",
      user: @anonymous_user,
      latitude: 33.0,
      longitude: 130.0,
      is_reference: true,
      region: "jp"
    )

    hokkaido = Farm.create!(
      name: "北海道農場",
      user: @anonymous_user,
      latitude: 43.0,
      longitude: 141.0,
      is_reference: true,
      region: "jp"
    )

    tokyo = Farm.create!(
      name: "東京農場",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 139.0,
      is_reference: true,
      region: "jp"
    )

    # 参照農場は北から南の順（緯度降順）
    jp_farms = Farm.reference.by_region("jp")
    assert_equal [hokkaido, tokyo, kyushu], jp_farms.to_a
  end

  # ====================================================================
  # R5: データの独立性のテスト
  # ====================================================================

  test "R5: regions should have independent data sets" do
    # 日本のデータセット
    jp_farm = Farm.create!(
      name: "Sample Farm",
      user: @anonymous_user,
      latitude: 35.0,
      longitude: 135.0,
      is_reference: true,
      region: "jp"
    )

    jp_crop = Crop.create!(
      name: "Sample Crop",
      is_reference: true,
      region: "jp",
      revenue_per_area: 5000
    )

    # アメリカのデータセット（同じ名前だが異なるデータ）
    us_farm = Farm.create!(
      name: "Sample Farm",
      user: @anonymous_user,
      latitude: 42.0,
      longitude: -93.0,
      is_reference: true,
      region: "us"
    )

    us_crop = Crop.create!(
      name: "Sample Crop",
      is_reference: true,
      region: "us",
      revenue_per_area: 8000
    )

    # 独立して存在できる
    assert jp_farm.valid?
    assert us_farm.valid?
    assert jp_crop.valid?
    assert us_crop.valid?

    # 地域別に取得される
    assert_equal 1, Farm.reference.by_region("jp").where(name: "Sample Farm").count
    assert_equal 1, Farm.reference.by_region("us").where(name: "Sample Farm").count
    assert_equal 1, Crop.reference.by_region("jp").where(name: "Sample Crop").count
    assert_equal 1, Crop.reference.by_region("us").where(name: "Sample Crop").count

    # 互いに干渉しない
    assert_not_equal jp_crop.revenue_per_area, us_crop.revenue_per_area
  end

  test "R5: users can create custom data for any region" do
    # ユーザーが日本向けのカスタムデータを作成
    user_farm_jp = Farm.create!(
      name: "私の農場",
      user: @user,
      latitude: 35.0,
      longitude: 135.0,
      region: "jp"
    )

    user_crop_jp = Crop.create!(
      name: "特殊品種イチゴ",
      variety: "あまおう",
      user: @user,
      is_reference: false,
      region: "jp",
      area_per_unit: 0.1,
      revenue_per_area: 15000
    )

    user_rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "特殊グループ",
      target_group: "特殊グループ",
      impact_ratio: 0.5,
      description: "ユーザー独自の輪作ルール",
      user: @user,
      is_reference: false,
      region: "jp"
    )

    # 全てが地域を持つ
    assert_equal "jp", user_farm_jp.region
    assert_equal "jp", user_crop_jp.region
    assert_equal "jp", user_rule_jp.region

    # 全てがユーザーデータ
    assert_not user_farm_jp.is_reference
    assert_not user_crop_jp.is_reference
    assert_not user_rule_jp.is_reference

    # ユーザーのデータとしてフィルタリング可能
    assert_includes Farm.user_owned.by_user(@user).by_region("jp"), user_farm_jp
    assert_includes Crop.user_owned.by_region("jp"), user_crop_jp
    assert_includes InteractionRule.user_owned.by_region("jp"), user_rule_jp
  end

  # ====================================================================
  # 統合シナリオテスト
  # ====================================================================

  test "SCENARIO: Japanese user gets complete regional dataset" do
    # 日本の完全なデータセットを構築
    
    # 参照農場
    tokyo_farm = Farm.create!(
      name: "東京サンプル農場",
      user: @anonymous_user,
      latitude: 35.68,
      longitude: 139.65,
      is_reference: true,
      region: "jp"
    )

    # 参照作物
    rice = Crop.create!(
      name: "コシヒカリ",
      variety: "水稲",
      is_reference: true,
      region: "jp",
      area_per_unit: 0.25,
      revenue_per_area: 5000,
      groups: ["イネ科"]
    )

    soybean = Crop.create!(
      name: "大豆",
      variety: "エンレイ",
      is_reference: true,
      region: "jp",
      area_per_unit: 0.3,
      revenue_per_area: 3000,
      groups: ["マメ科"]
    )

    # 参照輪作ルール
    rice_rotation = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "マメ科",
      target_group: "イネ科",
      impact_ratio: 1.1,
      description: "マメ科後のイネ科は増収",
      is_reference: true,
      is_directional: true,
      region: "jp"
    )

    # 日本のユーザーがデータセットを取得
    jp_dataset = {
      farms: Farm.reference.by_region("jp"),
      crops: Crop.reference.by_region("jp"),
      rules: InteractionRule.reference.by_region("jp")
    }

    # 完全なデータセットが取得できる
    assert_equal 1, jp_dataset[:farms].count
    assert_equal 2, jp_dataset[:crops].count
    assert_equal 1, jp_dataset[:rules].count

    # 全て日本のデータ
    assert jp_dataset[:farms].all? { |f| f.region == "jp" }
    assert jp_dataset[:crops].all? { |c| c.region == "jp" }
    assert jp_dataset[:rules].all? { |r| r.region == "jp" }

    # 全て参照データ
    assert jp_dataset[:farms].all?(&:is_reference)
    assert jp_dataset[:crops].all?(&:is_reference)
    assert jp_dataset[:rules].all?(&:is_reference)
  end

  test "SCENARIO: American user gets different regional dataset" do
    # アメリカの完全なデータセットを構築
    
    # 参照農場
    iowa_farm = Farm.create!(
      name: "Iowa Corn Belt",
      user: @anonymous_user,
      latitude: 42.03,
      longitude: -93.63,
      is_reference: true,
      region: "us"
    )

    # 参照作物
    corn = Crop.create!(
      name: "Corn",
      variety: "Field Corn",
      is_reference: true,
      region: "us",
      area_per_unit: 1.0,
      revenue_per_area: 8000,
      groups: ["Poaceae"]
    )

    soybean = Crop.create!(
      name: "Soybean",
      variety: "Glycine max",
      is_reference: true,
      region: "us",
      area_per_unit: 1.0,
      revenue_per_area: 6000,
      groups: ["Fabaceae"]
    )

    # 参照輪作ルール
    corn_rotation = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Fabaceae",
      target_group: "Poaceae",
      impact_ratio: 1.15,
      description: "Corn after soybean boost",
      is_reference: true,
      is_directional: true,
      region: "us"
    )

    # アメリカのユーザーがデータセットを取得
    us_dataset = {
      farms: Farm.reference.by_region("us"),
      crops: Crop.reference.by_region("us"),
      rules: InteractionRule.reference.by_region("us")
    }

    # 完全なデータセットが取得できる
    assert_equal 1, us_dataset[:farms].count
    assert_equal 2, us_dataset[:crops].count
    assert_equal 1, us_dataset[:rules].count

    # 全てアメリカのデータ
    assert us_dataset[:farms].all? { |f| f.region == "us" }
    assert us_dataset[:crops].all? { |c| c.region == "us" }
    assert us_dataset[:rules].all? { |r| r.region == "us" }

    # 全て参照データ
    assert us_dataset[:farms].all?(&:is_reference)
    assert us_dataset[:crops].all?(&:is_reference)
    assert us_dataset[:rules].all?(&:is_reference)
  end
end

