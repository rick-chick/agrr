# frozen_string_literal: true

require "test_helper"

class InteractionRuleRegionTest < ActiveSupport::TestCase
  def setup
    @user = users(:one)
  end

  # 基本的なCRUD操作

  test "should create interaction_rule without region" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    
    assert_nil rule.region
    rule.reload
    assert_nil rule.region
  end

  test "should create interaction_rule with jp region" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      region: "jp"
    )
    
    assert_equal "jp", rule.region
    rule.reload
    assert_equal "jp", rule.region
  end

  test "should create interaction_rule with us region" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Brassicaceae",
      target_group: "Brassicaceae",
      impact_ratio: 0.8,
      region: "us"
    )
    
    assert_equal "us", rule.region
    rule.reload
    assert_equal "us", rule.region
  end

  test "should update interaction_rule region" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Fabaceae",
      target_group: "Fabaceae",
      impact_ratio: 0.9
    )
    
    rule.update!(region: "jp")
    assert_equal "jp", rule.region
  end

  # by_regionスコープのテスト

  test "by_region scope should return only rules with specified region" do
    # 既存のJP地域のルールをクリア
    InteractionRule.where(region: "jp").destroy_all
    
    rule_jp1 = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      region: "jp"
    )
    
    rule_jp2 = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Brassicaceae",
      target_group: "Brassicaceae",
      impact_ratio: 0.8,
      region: "jp"
    )
    
    rule_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Fabaceae",
      target_group: "Fabaceae",
      impact_ratio: 0.9,
      region: "us"
    )
    
    rule_global = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Cucurbitaceae",
      target_group: "Cucurbitaceae",
      impact_ratio: 0.85
    )
    
    jp_rules = InteractionRule.by_region("jp")
    
    assert_equal 2, jp_rules.count
    assert_includes jp_rules, rule_jp1
    assert_includes jp_rules, rule_jp2
    assert_not_includes jp_rules, rule_us
    assert_not_includes jp_rules, rule_global
  end

  test "by_region scope should work with reference scope" do
    # 参照ルール（システム提供）
    ref_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      is_reference: true,
      region: "jp"
    )
    
    ref_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.6,
      is_reference: true,
      region: "us"
    )
    
    # ユーザールール
    user_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Brassicaceae",
      target_group: "Brassicaceae",
      impact_ratio: 0.8,
      user: @user,
      is_reference: false,
      region: "jp"
    )
    
    # 日本の参照ルールのみを取得
    jp_reference_rules = InteractionRule.reference.by_region("jp")
    
    assert_equal 1, jp_reference_rules.count
    assert_includes jp_reference_rules, ref_jp
    assert_not_includes jp_reference_rules, ref_us
    assert_not_includes jp_reference_rules, user_jp
  end

  # 実際の使用シナリオ

  test "should support providing region-specific interaction rules" do
    # 日本用の連作・輪作ルール
    # 日本では稲作と大豆の輪作が一般的
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
    
    # アメリカ用の連作・輪作ルール
    # アメリカではトウモロコシと大豆の輪作が主流
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
    
    # 日本のルールを取得
    jp_interaction_rules = InteractionRule.reference.by_region("jp")
    assert_equal 2, jp_interaction_rules.count
    jp_interaction_rules.each do |rule|
      assert_equal "jp", rule.region
      assert rule.is_reference
    end
    
    # アメリカのルールを取得
    us_interaction_rules = InteractionRule.reference.by_region("us")
    assert_equal 2, us_interaction_rules.count
    us_interaction_rules.each do |rule|
      assert_equal "us", rule.region
      assert rule.is_reference
    end
  end

  test "should allow different impact ratios for same crop groups in different regions" do
    # 日本のナス科連作ペナルティ（土壌病害リスクが高い）
    jp_rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.6,  # 40%減収
      description: "日本の高湿度環境では病害リスク大",
      is_reference: true,
      region: "jp"
    )
    
    # アメリカのナス科連作ペナルティ（比較的軽微）
    us_rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.8,  # 20%減収
      description: "Moderate continuous cropping penalty",
      is_reference: true,
      region: "us"
    )
    
    assert_equal "Solanaceae", jp_rule.source_group
    assert_equal "Solanaceae", us_rule.source_group
    assert_not_equal jp_rule.impact_ratio, us_rule.impact_ratio
    
    # 地域によって異なる影響係数が適用される
    assert jp_rule.impact_ratio < us_rule.impact_ratio
  end

  test "should support user creating custom rules for specific region" do
    # ユーザーが日本向けのカスタムルールを作成
    custom_rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "特殊グループ",
      target_group: "特殊グループ",
      impact_ratio: 0.5,
      description: "ユーザー独自の輪作ルール",
      user: @user,
      is_reference: false,
      region: "jp"
    )
    
    assert_equal "jp", custom_rule.region
    assert_equal @user, custom_rule.user
    assert_not custom_rule.is_reference
  end

  test "should export region-specific rules to agrr CLI format" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      description: "Test rule for JP region",
      is_reference: true,
      region: "jp"
    )
    
    agrr_format = rule.to_agrr_format
    
    assert_equal "continuous_cultivation", agrr_format["rule_type"]
    assert_equal "Solanaceae", agrr_format["source_group"]
    assert_equal "Solanaceae", agrr_format["target_group"]
    assert_equal 0.7, agrr_format["impact_ratio"]
    
    # regionはagrr CLIフォーマットには含まれない（アプリ側でフィルタリング）
    # agrr CLIには地域でフィルタリング済みのルールを渡す
  end

  test "should handle multiple rules with same groups but different regions" do
    # 既存のSolanaceaeルールをクリア
    InteractionRule.where(source_group: "Solanaceae", target_group: "Solanaceae").destroy_all
    
    rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      region: "jp"
    )
    
    rule_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.8,
      region: "us"
    )
    
    rule_global = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.75
    )
    
    assert_equal 3, InteractionRule.where(
      source_group: "Solanaceae",
      target_group: "Solanaceae"
    ).count
    
    # 各地域で独立して管理できる
    assert_equal 1, InteractionRule.by_region("jp").where(source_group: "Solanaceae").count
    assert_equal 1, InteractionRule.by_region("us").where(source_group: "Solanaceae").count
  end
end

