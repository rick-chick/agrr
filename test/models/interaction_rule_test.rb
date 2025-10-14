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
      rule_type: "companion_planting",
      source_group: "Solanaceae",
      target_group: "Lamiaceae",
      impact_ratio: 1.15,
      is_directional: false,
      description: "Tomato and basil companion planting"
    )
    assert_equal false, rule.is_directional
  end

  test "should accept valid impact_ratio values" do
    rule = InteractionRule.create!(
      rule_type: "beneficial_rotation",
      source_group: "Fabaceae",
      target_group: "Poaceae",
      impact_ratio: 1.2
    )
    assert_equal 1.2, rule.impact_ratio
  end

  test "should accept zero impact_ratio" do
    rule = InteractionRule.create!(
      rule_type: "allelopathy",
      source_group: "Juglandaceae",
      target_group: "other_plants",
      impact_ratio: 0.0,
      description: "Walnut prevents cultivation"
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
      rule_type: "soil_compatibility",
      source_group: "field_001",
      target_group: "Fabaceae",
      impact_ratio: 1.2,
      is_directional: true,
      description: "Field 001 is suitable for legumes"
    )
    
    rule.reload
    assert_equal "soil_compatibility", rule.rule_type
    assert_equal "field_001", rule.source_group
    assert_equal "Fabaceae", rule.target_group
    assert_equal 1.2, rule.impact_ratio
    assert_equal true, rule.is_directional
    assert_equal "Field 001 is suitable for legumes", rule.description
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

  test "should handle multiple rules with same groups but different types" do
    rule1 = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.7
    )
    
    rule2 = InteractionRule.create!(
      rule_type: "allelopathy",
      source_group: "Solanaceae",
      target_group: "Solanaceae",
      impact_ratio: 0.9
    )
    
    assert_not_equal rule1.id, rule2.id
    assert_equal 2, InteractionRule.where(source_group: "Solanaceae", target_group: "Solanaceae").count
  end
end

