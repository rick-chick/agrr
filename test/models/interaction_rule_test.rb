# frozen_string_literal: true

require 'test_helper'

class InteractionRuleTest < ActiveSupport::TestCase
  test "should create interaction_rule with valid attributes" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      is_directional: true,
      description: "Continuous cultivation penalty for Solanaceae"
    )
    assert rule.valid?
    assert rule.save
  end

  test "should require rule_type" do
    rule = InteractionRule.new(
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    assert_not rule.valid?
    assert_includes rule.errors[:rule_type], "can't be blank"
  end

  test "should require source_group" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    assert_not rule.valid?
    assert_includes rule.errors[:source_group], "can't be blank"
  end

  test "should require target_group" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      impact_ratio: 0.7
    )
    assert_not rule.valid?
    assert_includes rule.errors[:target_group], "can't be blank"
  end

  test "should require impact_ratio" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae"
    )
    assert_not rule.valid?
    assert_includes rule.errors[:impact_ratio], "can't be blank"
  end

  test "should default is_directional to true" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    assert_equal true, rule.is_directional
  end

  test "should allow is_directional to be false" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      is_directional: false,
      description: "Bidirectional continuous cultivation penalty"
    )
    assert_equal false, rule.is_directional
  end

  test "should accept valid impact_ratio values" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.6
    )
    assert_equal 0.6, rule.impact_ratio
  end

  test "should accept zero impact_ratio" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.0,
      description: "Severe continuous cultivation prevents cultivation"
    )
    assert rule.valid?
    assert_equal 0.0, rule.impact_ratio
  end

  test "should not allow negative impact_ratio" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: -0.5
    )
    assert_not rule.valid?
    assert_includes rule.errors[:impact_ratio], "must be greater than or equal to 0"
  end

  test "should allow description to be nil" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      description: nil
    )
    assert rule.valid?
    assert_nil rule.description
  end

  test "should persist all attributes after reload" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.65,
      is_directional: true,
      description: "Continuous cultivation penalty for Solanaceae"
    )
    
    rule.reload
    assert_equal "continuous_cultivation", rule.rule_type
    assert_equal "Solanaceae", rule.source_group
    assert_equal "Solanaceae", rule.target_group
    assert_equal 0.65, rule.impact_ratio
    assert_equal true, rule.is_directional
    assert_equal "Continuous cultivation penalty for Solanaceae", rule.description
  end

  test "should update attributes" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    
    rule.update!(
      impact_ratio: 0.8,
      description: "Updated penalty rate"
    )
    
    assert_equal 0.8, rule.impact_ratio
    assert_equal "Updated penalty rate", rule.description
  end

  test "should return JSON format compatible with agrr CLI" do
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      is_directional: true,
      description: "Continuous cultivation penalty"
    )
    
    json = rule.as_json
    
    assert_equal "continuous_cultivation", json["rule_type"]
    assert_equal "Solanaceae", json["source_group"]
    assert_equal "Solanaceae", json["target_group"]
    assert_equal 0.7, json["impact_ratio"]
    assert_equal true, json["is_directional"]
    assert_equal "Continuous cultivation penalty", json["description"]
  end

  test "should handle multiple rules with same type and groups" do
    rule1 = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      description: "Standard continuous cultivation penalty"
    )
    
    rule2 = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.6,
      description: "Severe continuous cultivation penalty"
    )
    
    assert_not_equal rule1.id, rule2.id
    assert_equal 2, InteractionRule.where(source_group: "Solanaceae", target_group: "Solanaceae").count
  end

  test "by_region scope should filter by region" do
    rule_jp = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7,
      region: "jp"
    )
    
    rule_us = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Brassicaceae",
      target_group: "Brassicaceae",
      impact_ratio: 0.8,
      region: "us"
    )
    
    rule_no_region = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Fabaceae",
      target_group: "Fabaceae",
      impact_ratio: 0.9
    )
    
    jp_rules = InteractionRule.by_region("jp")
    assert_includes jp_rules, rule_jp
    assert_not_includes jp_rules, rule_us
    assert_not_includes jp_rules, rule_no_region
    
    us_rules = InteractionRule.by_region("us")
    assert_includes us_rules, rule_us
    assert_not_includes us_rules, rule_jp
  end

  test "should save interaction_rule with region" do
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
end

