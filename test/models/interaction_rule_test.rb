# frozen_string_literal: true

require "test_helper"

class InteractionRuleTest < ActiveSupport::TestCase
  test "should validate is_reference inclusion" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "ナス科",
      target_group: "ナス科",
      impact_ratio: 0.7,
      is_reference: nil
    )

    assert_not rule.valid?
    assert_includes rule.errors[:is_reference], "は一覧にありません"
  end

  test "should validate user presence when is_reference is false" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "ナス科",
      target_group: "ナス科",
      impact_ratio: 0.7,
      is_reference: false,
      user_id: nil
    )

    assert_not rule.valid?
    assert_includes rule.errors[:user], "を入力してください"
  end

  test "should allow nil user_id when is_reference is true" do
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "ナス科",
      target_group: "ナス科",
      impact_ratio: 0.7,
      is_reference: true,
      user_id: nil
    )

    assert rule.valid?
  end

  test "should not allow user for reference rules" do
    user = create(:user)
    rule = InteractionRule.new(
      rule_type: "continuous_cultivation",
      source_group: "ナス科",
      target_group: "ナス科",
      impact_ratio: 0.7,
      is_reference: true,
      user: user
    )
    rule.valid?

    assert_includes rule.errors[:user], "は参照データには設定できません"
  end
end

