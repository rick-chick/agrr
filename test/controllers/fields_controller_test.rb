# frozen_string_literal: true

require 'test_helper'

class FieldsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user)
  end

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    field = create(:field, farm: @farm, user: @user)

    assert_difference -> { Field.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete farm_field_path(@farm, field), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'Field', event.resource_type
    assert_equal field.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal farm_fields_path(@farm, locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(field), body.fetch('resource_dom_id')
    assert_equal field.display_name, body.fetch('resource')
  end

  test 'undo_endpoint_restores_field' do
    sign_in_as @user
    field = create(:field, farm: @farm, user: @user)

    delete farm_field_path(@farm, field), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not Field.exists?(field.id), '削除後にFieldが残っています'

    assert_difference -> { Field.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert Field.exists?(field.id), 'Undo後にFieldが復元されていません'
  end

  # TODO: destroyアクションのHTMLレスポンスに対するリダイレクトとflashのテストを追加する
end
