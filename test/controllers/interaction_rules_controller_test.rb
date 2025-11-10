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

  # TODO: destroyアクションのHTMLレスポンスのテストを追加する
end

