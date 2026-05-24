# frozen_string_literal: true

require "test_helper"

class InteractionRulesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
  end


  def create_interaction_rule(user:)
    InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "GroupA",
      target_group: "GroupB",
      impact_ratio: 1.0,
      is_directional: true,
      description: "テスト用の相互作用ルール",
      is_reference: false,
      user: user
    )
  end

  # ========== index アクションのテスト ==========
  #
  # index の絞り込み（一般ユーザーは自分のルールのみ／管理者は参照ルールも）は
  # InteractionRuleListInteractor のユニットテストが担保する。テンプレートの行描画は
  # test/views/interaction_rules_index_view_test.rb が担保する。
  # ここは各ロールで index アクションの配線が通ることのみ確認する。

  test "一般ユーザーの index は正常に描画される" do
    sign_in_as @user
    create_interaction_rule(user: @user)

    get interaction_rules_path
    assert_response :success
  end

  test "管理者の index は正常に描画される" do
    admin = create(:user, admin: true)
    sign_in_as admin
    create_interaction_rule(user: admin)
    InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "RefSourceAdmin",
      target_group: "RefTargetAdmin",
      impact_ratio: 1.0,
      is_directional: true,
      description: "参照ルール",
      is_reference: true,
      user_id: nil
    )

    get interaction_rules_path
    assert_response :success
  end

  test "destroy_via_html_redirects_with_undo_notice" do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    expected_label = "#{InteractionRule.model_name.human} ##{interaction_rule.id}"

    assert_difference -> { InteractionRule.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete interaction_rule_path(interaction_rule) # HTMLリクエスト
        assert_redirected_to interaction_rules_path
      end
    end

    expected_notice = I18n.t(
      "deletion_undo.redirect_notice",
      resource: expected_label
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== バリデーション（HTML 応答形） ==========
  #
  # is_reference / region 認可は Interactor テストと API controller テストが担保する。
  # HTML の redirect + flash マッピングは ERB 廃止（Phase 5）に伴いここでは検証しない。

  test "作成時に必須項目が欠けていると一覧へリダイレクトする" do
    sign_in_as @user

    assert_no_difference("InteractionRule.count") do
      post interaction_rules_path, params: {
        interaction_rule: {
          rule_type: "",
          source_group: "",
          target_group: "",
          impact_ratio: nil
        }
      }
    end

    assert_redirected_to interaction_rules_path
    assert_predicate flash[:alert], :present?
  end

  test "update時に必須項目が欠けていると詳細へリダイレクトする" do
    sign_in_as @user
    rule = create_interaction_rule(user: @user)
    original_rule_type = rule.rule_type

    patch interaction_rule_path(rule), params: {
      interaction_rule: {
        rule_type: "",
        source_group: rule.source_group,
        target_group: rule.target_group,
        impact_ratio: rule.impact_ratio
      }
    }

    assert_redirected_to interaction_rule_path(rule)
    assert_predicate flash[:alert], :present?

    rule.reload
    assert_equal original_rule_type, rule.rule_type
  end
end
