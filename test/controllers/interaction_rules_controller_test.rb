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

  test "destroy_returns_undo_token_json" do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    assert_difference -> { InteractionRule.count }, -1 do
      assert_difference "DeletionUndoEvent.count", +1 do
        delete interaction_rule_path(interaction_rule), as: :json
        assert_response :success
      end
    end

    body = @response.parsed_body
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body.fetch("undo_token")
    event = DeletionUndoEvent.find(undo_token)
    assert_equal "InteractionRule", event.resource_type
    assert_equal interaction_rule.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch("undo_path")
    assert_equal interaction_rules_path(locale: I18n.locale), body.fetch("redirect_path")
    assert_equal dom_id(interaction_rule), body.fetch("resource_dom_id")
    expected_label = "#{InteractionRule.model_name.human} ##{interaction_rule.id}"
    assert_equal expected_label, body.fetch("resource")
  end

  test "undo_endpoint_restores_interaction_rule" do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    assert_difference -> { InteractionRule.count }, -1 do
      delete interaction_rule_path(interaction_rule), as: :json
      assert_response :success
    end

    body = @response.parsed_body
    undo_token = body.fetch("undo_token")

    assert_not InteractionRule.exists?(interaction_rule.id), "削除後にInteractionRuleが残っています"

    assert_difference -> { InteractionRule.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = @response.parsed_body
    assert_equal "restored", undo_body.fetch("status")
    assert_equal undo_token, undo_body.fetch("undo_token")

    event = DeletionUndoEvent.find(undo_token)
    assert_equal "restored", event.state
    assert InteractionRule.exists?(interaction_rule.id), "Undo後にInteractionRuleが復元されていません"
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

  # ========== region / is_reference 認可 ==========
  #
  # region（admin のみ設定可）の認可は InteractionRulePolicy が判定する。
  #   → test/policies/interaction_rule_policy_test.rb
  #     test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb
  #     test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb
  # is_reference（admin のみ設定/変更可）の認可は Create/Update Interactor が判定する。
  #   → 同上 interactor テスト
  # 以下の controller テストは、認可失敗が HTTP 応答（redirect + flash）へ
  # 正しくマッピングされる境界のみを検証する。

  test "一般ユーザーの参照ルール作成失敗は redirect + flash へマッピングされる" do
    sign_in_as @user

    post interaction_rules_path, params: {
      interaction_rule: {
        rule_type: "continuous_cultivation",
        source_group: "UserSource",
        target_group: "UserTarget",
        impact_ratio: 1.0,
        is_reference: true
      }
    }

    assert_redirected_to interaction_rules_path
    assert_equal I18n.t("interaction_rules.flash.reference_only_admin"), flash[:alert]
  end

  test "作成時に必須項目が欠けていると422でnewを再表示する" do
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

    assert_response :unprocessable_entity
  end

  test "一般ユーザーの is_reference 変更失敗は redirect + flash へマッピングされる" do
    sign_in_as @user
    rule = create_interaction_rule(user: @user)

    patch interaction_rule_path(rule), params: {
      interaction_rule: {
        rule_type: rule.rule_type,
        source_group: rule.source_group,
        target_group: rule.target_group,
        impact_ratio: rule.impact_ratio,
        is_reference: true
      }
    }

    assert_redirected_to interaction_rule_path(rule)
    assert_equal I18n.t("interaction_rules.flash.reference_flag_admin_only"), flash[:alert]
  end

  test "update時に必須項目が欠けていると422でeditを再表示する" do
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

    assert_response :unprocessable_entity

    rule.reload
    assert_equal original_rule_type, rule.rule_type
  end
end
