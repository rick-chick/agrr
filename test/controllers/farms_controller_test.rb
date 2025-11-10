# frozen_string_literal: true

require 'test_helper'

class FarmsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
  end

  test 'destroy_returns_undo_token_json' do
    sign_in_as @user
    farm = create(:farm, user: @user)

    assert_difference -> { Farm.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete farm_path(farm), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after redirect_path resource_dom_id resource].each do |key|
      assert body.key?(key), "JSONレスポンスに#{key}が含まれていません"
      assert body[key].present?, "#{key} が空です"
    end

    undo_token = body['undo_token']
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'Farm', event.resource_type
    assert_equal farm.id.to_s, event.resource_id
    assert event.scheduled?
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal farms_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(farm), body.fetch('resource_dom_id')
    assert_equal farm.display_name, body.fetch('resource')
  end

  test 'undo_endpoint_restores_farm' do
    sign_in_as @user
    farm = create(:farm, user: @user)

    delete farm_path(farm), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')

    assert_not Farm.exists?(farm.id), '削除後にFarmが残っています'

    assert_difference -> { Farm.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body['status']
    assert_equal undo_token, undo_body['undo_token']

    restored_event = DeletionUndoEvent.find(undo_token)
    assert restored_event.restored?
    assert Farm.exists?(farm.id), 'Undo後にFarmが復元されていません'
  end

  # TODO: destroyアクションのHTMLレスポンスに対するリダイレクトフローのテストを追加する
end

