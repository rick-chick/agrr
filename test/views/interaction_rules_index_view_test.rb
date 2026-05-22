# frozen_string_literal: true

require "test_helper"

# interaction_rules/index テンプレートの描画責務。
# 「一般ユーザーは自分のルールのみ／管理者は参照ルールも」という絞り込み（ユースケース判定）は
# InteractionRuleListInteractor のユニットテストが担保する。ここは Interactor が渡した
# ルールエンティティをテンプレートがどう HTML 行に写すかだけを検証する。
class InteractionRulesIndexViewTest < ActiveSupport::TestCase
  def rule_entity(id:, source_group:, target_group:, is_reference: false)
    Domain::InteractionRule::Entities::InteractionRuleEntity.new(
      id: id,
      user_id: is_reference ? nil : 1,
      rule_type: "continuous_cultivation",
      source_group: source_group,
      target_group: target_group,
      impact_ratio: 1.0,
      is_directional: true,
      description: nil,
      region: nil,
      is_reference: is_reference
    )
  end

  test "index は @interaction_rules の非参照ルールを source / target 付きの行として描画する" do
    rule = rule_entity(id: 1, source_group: "OwnSource", target_group: "OwnTarget")

    html = InteractionRulesController.renderer.render(
      template: "interaction_rules/index",
      layout: false,
      assigns: { interaction_rules: [ rule ], reference_rules: [] }
    )

    assert_includes html, "OwnSource"
    assert_includes html, "OwnTarget"
    assert_includes html, %(id="interaction_rule_#{rule.id}")
  end

  test "index は @interaction_rules 内の参照ルール行をスキップする" do
    reference_rule = rule_entity(id: 2, source_group: "RefSource", target_group: "RefTarget", is_reference: true)

    html = InteractionRulesController.renderer.render(
      template: "interaction_rules/index",
      layout: false,
      assigns: { interaction_rules: [ reference_rule ], reference_rules: [] }
    )

    refute_includes html, %(id="interaction_rule_#{reference_rule.id}")
  end
end
