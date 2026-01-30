# frozen_string_literal: true

require 'test_helper'

class InteractionRulesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
  end


  def create_interaction_rule(user:)
    InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'GroupA',
      target_group: 'GroupB',
      impact_ratio: 1.0,
      is_directional: true,
      description: 'テスト用の相互作用ルール',
      is_reference: false,
      user: user
    )
  end

  # ========== index アクションのテスト ==========

  test '一般ユーザーのindexは自身のルールのみ表示し参照ルールは表示しない' do
    sign_in_as @user

    own_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'OwnSource',
      target_group: 'OwnTarget',
      impact_ratio: 1.0,
      is_directional: true,
      description: '自分のルール',
      is_reference: false,
      user: @user
    )
    other_user = create(:user)
    other_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'OtherSource',
      target_group: 'OtherTarget',
      impact_ratio: 1.0,
      is_directional: true,
      description: '他人のルール',
      is_reference: false,
      user: other_user
    )
    reference_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'RefSource',
      target_group: 'RefTarget',
      impact_ratio: 1.0,
      is_directional: true,
      description: '参照ルール',
      is_reference: true,
      user_id: nil
    )

    get interaction_rules_path
    assert_response :success

    body = response.body
    assert_includes body, own_rule.source_group
    assert_includes body, own_rule.target_group
    refute_includes body, other_rule.source_group
    refute_includes body, other_rule.target_group
    refute_includes body, reference_rule.source_group
    refute_includes body, reference_rule.target_group
  end

  test '管理者のindexは自身のルールと参照ルールを表示し他人のルールは表示しない' do
    admin = create(:user, admin: true)
    sign_in_as admin

    admin_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'AdminSource',
      target_group: 'AdminTarget',
      impact_ratio: 1.0,
      is_directional: true,
      description: '管理者のルール',
      is_reference: false,
      user: admin
    )
    other_user = create(:user)
    other_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'OtherUserSource',
      target_group: 'OtherUserTarget',
      impact_ratio: 1.0,
      is_directional: true,
      description: '他人のルール',
      is_reference: false,
      user: other_user
    )
    reference_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'RefSourceAdmin',
      target_group: 'RefTargetAdmin',
      impact_ratio: 1.0,
      is_directional: true,
      description: '参照ルール',
      is_reference: true,
      user_id: nil
    )

    get interaction_rules_path
    assert_response :success

    body = response.body
    assert_includes body, admin_rule.source_group
    assert_includes body, admin_rule.target_group
    assert_includes body, reference_rule.source_group
    assert_includes body, reference_rule.target_group
    refute_includes body, other_rule.source_group
    refute_includes body, other_rule.target_group
  end

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    assert_difference -> { InteractionRule.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete interaction_rule_path(interaction_rule), as: :json
        assert_response :success
      end
    end

    body = @response.parsed_body
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'InteractionRule', event.resource_type
    assert_equal interaction_rule.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal interaction_rules_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(interaction_rule), body.fetch('resource_dom_id')
    expected_label = "#{InteractionRule.model_name.human} ##{interaction_rule.id}"
    assert_equal expected_label, body.fetch('resource')
  end

  test 'undo_endpoint_restores_interaction_rule' do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    assert_difference -> { InteractionRule.count }, -1 do
      delete interaction_rule_path(interaction_rule), as: :json
      assert_response :success
    end

    body = @response.parsed_body
    undo_token = body.fetch('undo_token')

    assert_not InteractionRule.exists?(interaction_rule.id), '削除後にInteractionRuleが残っています'

    assert_difference -> { InteractionRule.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = @response.parsed_body
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'restored', event.state
    assert InteractionRule.exists?(interaction_rule.id), 'Undo後にInteractionRuleが復元されていません'
  end

  test 'destroy_via_html_redirects_with_undo_notice' do
    sign_in_as @user
    interaction_rule = create_interaction_rule(user: @user)

    expected_label = "#{InteractionRule.model_name.human} ##{interaction_rule.id}"

    assert_difference -> { InteractionRule.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete interaction_rule_path(interaction_rule) # HTMLリクエスト
        assert_redirected_to interaction_rules_path
      end
    end

    expected_notice = I18n.t(
      'deletion_undo.redirect_notice',
      resource: expected_label
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== region編集のテスト ==========

  test "管理者は参照ルールのregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    ref_rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'GroupA',
      target_group: 'GroupB',
      impact_ratio: 1.0,
      is_reference: true,
      user_id: nil,
      region: 'jp'
    )
    
    patch interaction_rule_path(ref_rule), params: {
      interaction_rule: {
        rule_type: ref_rule.rule_type,
        source_group: ref_rule.source_group,
        target_group: ref_rule.target_group,
        impact_ratio: ref_rule.impact_ratio,
        region: 'us'
      }
    }
    
    assert_redirected_to interaction_rule_path(ref_rule)
    ref_rule.reload
    assert_equal 'us', ref_rule.region
  end

  test "管理者は自身のルールのregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'GroupA',
      target_group: 'GroupB',
      impact_ratio: 1.0,
      is_reference: false,
      user: admin,
      region: 'jp'
    )
    
    patch interaction_rule_path(rule), params: {
      interaction_rule: {
        rule_type: rule.rule_type,
        source_group: rule.source_group,
        target_group: rule.target_group,
        impact_ratio: rule.impact_ratio,
        region: 'in'
      }
    }
    
    assert_redirected_to interaction_rule_path(rule)
    rule.reload
    assert_equal 'in', rule.region
  end

  test "一般ユーザーはregionを更新できない" do
    sign_in_as @user
    rule = InteractionRule.create!(
      rule_type: 'continuous_cultivation',
      source_group: 'GroupA',
      target_group: 'GroupB',
      impact_ratio: 1.0,
      is_reference: false,
      user: @user,
      region: 'jp'
    )
    
    patch interaction_rule_path(rule), params: {
      interaction_rule: {
        rule_type: rule.rule_type,
        source_group: rule.source_group,
        target_group: rule.target_group,
        impact_ratio: rule.impact_ratio,
        region: 'us'
      }
    }
    
    assert_redirected_to interaction_rule_path(rule)
    rule.reload
    # regionは変更されない（パラメータに含まれても無視される）
    assert_equal 'jp', rule.region
  end

  test "管理者は新規ルール作成時にregionを設定できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    post interaction_rules_path, params: {
      interaction_rule: {
        rule_type: 'continuous_cultivation',
        source_group: 'GroupA',
        target_group: 'GroupB',
        impact_ratio: 1.0,
        is_reference: true,
        region: 'us'
      }
    }
    
    rule = InteractionRule.last
    assert_redirected_to interaction_rule_path(rule)
    assert_equal 'us', rule.region
    assert rule.is_reference?
    assert_nil rule.user_id
  end

  test "一般ユーザーは新規ルール作成時にregionを設定できない" do
    sign_in_as @user
    
    post interaction_rules_path, params: {
      interaction_rule: {
        rule_type: 'continuous_cultivation',
        source_group: 'GroupA',
        target_group: 'GroupB',
        impact_ratio: 1.0,
        region: 'us'
      }
    }
    
    assert_redirected_to interaction_rule_path(InteractionRule.last)
    rule = InteractionRule.last
    # regionは設定されない（パラメータに含まれても無視される）
    assert_nil rule.region
  end

  # ========== create / update の参照・権限制御 ==========

  test "一般ユーザーは参照ルールを作成できない" do
    sign_in_as @user

    assert_no_difference("InteractionRule.count") do
      post interaction_rules_path, params: {
        interaction_rule: {
          rule_type: "continuous_cultivation",
          source_group: "UserSource",
          target_group: "UserTarget",
          impact_ratio: 1.0,
          is_directional: true,
          description: "一般ユーザー参照ルール",
          is_reference: true
        }
      }
    end

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

  test "一般ユーザーはis_referenceフラグを変更できない" do
    sign_in_as @user
    rule = InteractionRule.create!(
      rule_type: "continuous_cultivation",
      source_group: "UserSource",
      target_group: "UserTarget",
      impact_ratio: 1.0,
      is_directional: true,
      description: "一般ユーザー用ルール",
      is_reference: false,
      user: @user
    )

    original_is_reference = rule.is_reference

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

    rule.reload
    assert_equal original_is_reference, rule.is_reference
    assert_equal @user.id, rule.user_id
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

