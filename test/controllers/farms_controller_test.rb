# frozen_string_literal: true

require 'test_helper'

class FarmsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
  end

  test "includes HtmlCrudResponder" do
    assert_includes FarmsController.included_modules, HtmlCrudResponder
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

  test 'destroy_via_html_redirects_with_undo_notice' do
    sign_in_as @user
    farm = create(:farm, user: @user, name: 'テスト農場')
    display_name = farm.display_name

    assert_difference -> { Farm.count }, -1 do
      assert_difference 'DeletionUndoEvent.count', +1 do
        delete farm_path(farm) # HTMLリクエスト
        assert_redirected_to farms_path
      end
    end

    expected_notice = I18n.t(
      'deletion_undo.redirect_notice',
      resource: display_name
    )
    assert_equal expected_notice, flash[:notice]
  end

  # ========== region編集のテスト ==========

  test "管理者は参照農場のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    ref_farm = create(:farm, is_reference: true, user: User.anonymous_user, region: 'jp')
    
    patch farm_path(ref_farm), params: {
      farm: {
        name: ref_farm.name,
        latitude: ref_farm.latitude,
        longitude: ref_farm.longitude,
        region: 'us'
      }
    }
    
    assert_redirected_to farm_path(ref_farm)
    ref_farm.reload
    assert_equal 'us', ref_farm.region
  end

  test "管理者は自身の農場のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    farm = create(:farm, user: admin, region: 'jp')
    
    patch farm_path(farm), params: {
      farm: {
        name: farm.name,
        latitude: farm.latitude,
        longitude: farm.longitude,
        region: 'in'
      }
    }
    
    assert_redirected_to farm_path(farm)
    farm.reload
    assert_equal 'in', farm.region
  end

  test "一般ユーザーはregionを更新できない" do
    sign_in_as @user
    farm = create(:farm, user: @user, region: 'jp')
    
    patch farm_path(farm), params: {
      farm: {
        name: farm.name,
        latitude: farm.latitude,
        longitude: farm.longitude,
        region: 'us'
      }
    }
    
    assert_redirected_to farm_path(farm)
    farm.reload
    # regionは変更されない（パラメータに含まれても無視される）
    assert_equal 'jp', farm.region
  end

  test "管理者は新規農場作成時にregionを設定できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    post farms_path, params: {
      farm: {
        name: '新規農場',
        latitude: 35.0,
        longitude: 139.0,
        region: 'us'
      }
    }
    
    assert_redirected_to farm_path(Farm.last)
    farm = Farm.last
    assert_equal 'us', farm.region
  end

  test "一般ユーザーは新規農場作成時にregionを設定できない" do
    sign_in_as @user
    
    post farms_path, params: {
      farm: {
        name: '新規農場',
        latitude: 35.0,
        longitude: 139.0,
        region: 'us'
      }
    }
    
    assert_redirected_to farm_path(Farm.last)
    farm = Farm.last
    # regionは設定されない（パラメータに含まれても無視される）
    assert_nil farm.region
  end
end

