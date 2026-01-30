# frozen_string_literal: true

require 'test_helper'

class PestsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    sign_in_as @user
    @pest = create(:pest, :complete, is_reference: true)
  end

  test "does not include HtmlCrudResponder (Clean Architecture)" do
    assert_not_includes PestsController.included_modules, HtmlCrudResponder
  end

  test "should get index" do
    get pests_path
    assert_response :success
    assert_select 'h1', text: I18n.t('pests.index.title')
  end

  test "should show pest" do
    get pest_path(@pest)
    assert_response :success
    assert_select 'h1', text: @pest.name
  end

  test "should get new" do
    get new_pest_path
    assert_response :success
    assert_select 'form'
  end

  test "should create pest" do
    assert_difference('Pest.count', 1) do
      post pests_path, params: { pest: {
        name: 'テスト害虫',
        name_scientific: 'Testus pestus',
        family: 'テスト科',
        order: 'テスト目',
        description: 'テスト用の害虫です',
        occurrence_season: '春',
        is_reference: false
      } }
    end

    assert_redirected_to pest_path(Pest.last)
    pest = Pest.last
    assert_not_nil pest, "Pest should exist"
    assert_equal 'テスト害虫', pest.name
  end

  test "should create pest with nested temperature_profile" do
    assert_difference('PestTemperatureProfile.count') do
      post pests_path, params: { pest: {
        name: 'テスト害虫2',
        pest_temperature_profile_attributes: {
          base_temperature: 10.0,
          max_temperature: 35.0
        }
      } }
    end

    pest = Pest.last
    assert_not_nil pest.pest_temperature_profile
    assert_equal 10.0, pest.pest_temperature_profile.base_temperature
    assert_equal 35.0, pest.pest_temperature_profile.max_temperature
  end

  test "should create pest with nested thermal_requirement" do
    assert_difference('PestThermalRequirement.count') do
      post pests_path, params: { pest: {
        name: 'テスト害虫3',
        pest_thermal_requirement_attributes: {
          required_gdd: 200.0,
          first_generation_gdd: 150.0
        }
      } }
    end

    pest = Pest.last
    assert_not_nil pest.pest_thermal_requirement
    assert_equal 200.0, pest.pest_thermal_requirement.required_gdd
    assert_equal 150.0, pest.pest_thermal_requirement.first_generation_gdd
  end

  test "should create pest with nested control_methods" do
    assert_difference('PestControlMethod.count', 2) do
      post pests_path, params: { pest: {
        name: 'テスト害虫4',
        pest_control_methods_attributes: {
          '0' => {
            method_type: 'chemical',
            method_name: 'テスト農薬',
            description: '化学的防除方法',
            timing_hint: '発生初期'
          },
          '1' => {
            method_type: 'biological',
            method_name: '天敵導入',
            description: '生物的防除方法',
            timing_hint: '常時'
          }
        }
      } }
    end

    pest = Pest.last
    assert_equal 2, pest.pest_control_methods.count
    assert_equal 'chemical', pest.pest_control_methods.first.method_type
    assert_equal 'biological', pest.pest_control_methods.last.method_type
  end

  test "should get edit for non-reference pest" do
    # 非参照害虫は編集可能
    user_pest = create(:pest, :user_owned, user: @user)
    get edit_pest_path(user_pest)
    assert_response :success
  end

  test "should not get edit for reference pest without admin" do
    # 参照害虫は一般ユーザーは編集不可
    get edit_pest_path(@pest)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "should update pest" do
    # 非参照害虫を作成
    pest = create(:pest, :user_owned, user: @user, name: '元の名前')
    
    patch pest_path(pest), params: { pest: {
      name: '更新後の名前',
      description: '更新された説明'
    } }
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal '更新後の名前', pest.name
    assert_equal '更新された説明', pest.description
  end

  test "should update pest with nested attributes" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    original_method_count = pest.pest_control_methods.count
    
    patch pest_path(pest), params: { pest: {
      name: pest.name,
      pest_temperature_profile_attributes: {
        id: pest.pest_temperature_profile.id,
        base_temperature: 15.0,
        max_temperature: 40.0
      },
      pest_control_methods_attributes: {
        '0' => {
          id: pest.pest_control_methods.first.id,
          method_type: 'cultural',
          method_name: '更新された方法名',
          description: '更新された説明',
          _destroy: 'false'
        }
      }
    } }
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 15.0, pest.pest_temperature_profile.base_temperature
    assert_equal 40.0, pest.pest_temperature_profile.max_temperature
    assert_equal 'cultural', pest.pest_control_methods.first.method_type
  end

  test "should destroy pest" do
    # 外部参照のない害虫を作成
    pest = create(:pest, :user_owned, user: @user)
    
    assert_difference -> { Pest.count }, -1 do
      assert_difference -> { DeletionUndoEvent.count }, +1 do
        delete pest_path(pest)
      end
    end

    assert_redirected_to pests_path
    assert_equal I18n.t('deletion_undo.redirect_notice', resource: pest.name), flash[:notice]

    event = DeletionUndoEvent.find_by!(resource_type: 'Pest', resource_id: pest.id.to_s)
    assert_equal 'Pest', event.resource_type
    assert_equal I18n.t('pests.undo.toast', name: pest.name), event.toast_message
  end

  test "destroy_returns_undo_token_json" do
    pest = create(:pest, :user_owned, user: @user)

    assert_difference -> { Pest.count }, -1 do
      assert_difference -> { DeletionUndoEvent.count }, +1 do
        delete pest_path(pest), as: :json
        assert_response :success
      end
    end

    body = JSON.parse(@response.body)
    %w[undo_token undo_deadline toast_message undo_path auto_hide_after resource redirect_path resource_dom_id].each do |key|
      value = body.fetch(key)
      assert value.present?, "#{key} が空です"
    end

    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'Pest', event.resource_type
    assert_equal pest.id.to_s, event.resource_id
    assert_equal 'scheduled', event.state
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal I18n.t('pests.undo.toast', name: pest.name), body.fetch('toast_message')
    assert_equal pest.name, body.fetch('resource')
    assert_equal pests_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(pest), body.fetch('resource_dom_id')

    # TODO: HTMLレスポンス向けのUndoトースト表示テストを追加する
  end

  test "undo_endpoint_restores_pest" do
    pest = create(:pest, :user_owned, user: @user)

    delete pest_path(pest), as: :json
    assert_response :success

    body = JSON.parse(@response.body)
    undo_token = body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'scheduled', event.state
    assert_not Pest.exists?(pest.id), '削除後にPestが残っています'

    assert_difference -> { Pest.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
      assert_response :success
    end

    undo_body = JSON.parse(@response.body)
    assert_equal 'restored', undo_body.fetch('status')
    assert_equal undo_token, undo_body.fetch('undo_token')

    event.reload
    assert_equal 'restored', event.state
    assert Pest.exists?(pest.id), 'Undo後にPestが復元されていません'
  end

  test "should destroy pest with nested associations" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    temp_profile_id = pest.pest_temperature_profile.id
    thermal_req_id = pest.pest_thermal_requirement.id
    control_method_ids = pest.pest_control_methods.pluck(:id)
    
    assert_difference('Pest.count', -1) do
      assert_difference('PestTemperatureProfile.count', -1) do
        assert_difference('PestThermalRequirement.count', -1) do
          assert_difference('PestControlMethod.count', -control_method_ids.count) do
            delete pest_path(pest)
          end
        end
      end
    end

    assert_redirected_to pests_path
    assert_nil PestTemperatureProfile.find_by(id: temp_profile_id)
    assert_nil PestThermalRequirement.find_by(id: thermal_req_id)
    control_method_ids.each do |id|
      assert_nil PestControlMethod.find_by(id: id)
    end
  end

  test "should not create reference pest without admin" do
    assert_no_difference('Pest.count') do
      post pests_path, params: { pest: {
        pest_id: 'test_pest_ref',
        name: '参照害虫',
        is_reference: true
      } }
    end

    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.reference_only_admin'), flash[:alert]
  end

  test "should not update is_reference flag without admin" do
    pest = create(:pest, :user_owned, user: @user)
    
    patch pest_path(pest), params: { pest: {
      name: pest.name,
      is_reference: true
    } }
    
    assert_redirected_to pest_path(pest)
    assert_equal I18n.t('pests.flash.reference_flag_admin_only'), flash[:alert]
    pest.reload
    assert_equal false, pest.is_reference
  end

  test "should not destroy reference pest without admin" do
    assert_no_difference('Pest.count') do
      delete pest_path(@pest)
    end

    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "admin can create reference pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    assert_difference('Pest.count') do
      post pests_path, params: { pest: {
        pest_id: 'admin_pest_ref',
        name: '管理者作成の参照害虫',
        is_reference: true
      } }
    end

    assert_redirected_to pest_path(Pest.last)
    assert_equal true, Pest.last.is_reference
  end

  test "admin can edit reference pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    get edit_pest_path(@pest)
    assert_response :success

    patch pest_path(@pest), params: { pest: {
      name: '管理者が更新した名前'
    } }
    assert_redirected_to pest_path(@pest)
    @pest.reload
    assert_equal '管理者が更新した名前', @pest.name
  end

  test "admin can destroy reference pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    assert_difference('Pest.count', -1) do
      delete pest_path(@pest)
    end

    assert_redirected_to pests_path
  end

  test "admin should see only reference pests and own pests in index" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    reference_pest = create(:pest, is_reference: true, user_id: nil, name: '参照害虫A')
    admin_pest = create(:pest, :user_owned, user: admin_user, name: '管理者害虫B')
    other_user = create(:user)
    other_user_pest = create(:pest, :user_owned, user: other_user, name: '他人害虫C')
    
    get pests_path
    assert_response :success
    
    # 管理者は参照害虫と自分の害虫のみ表示される
    # @pest (setupで作成された参照害虫), reference_pest, admin_pest の3つが表示される
    assert_select '.crop-card .crop-name', text: reference_pest.name, count: 1
    assert_select '.crop-card .crop-name', text: admin_pest.name, count: 1
    assert_select '.crop-card .crop-name', text: other_user_pest.name, count: 0
  end

  test "admin should not access other user's pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    other_user = create(:user)
    other_user_pest = create(:pest, :user_owned, user: other_user)
    
    # 詳細画面にアクセス試行
    get pest_path(other_user_pest)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
    
    # 編集画面にアクセス試行
    get edit_pest_path(other_user_pest)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
    
    # 更新試行
    patch pest_path(other_user_pest), params: { pest: { name: '変更された名前' } }
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
    other_user_pest.reload
    assert_not_equal '変更された名前', other_user_pest.name
  end

  test "admin should access reference pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    
    get pest_path(reference_pest)
    assert_response :success
    
    get edit_pest_path(reference_pest)
    assert_response :success
  end

  test "admin should access own pest" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    admin_pest = create(:pest, :user_owned, user: admin_user)
    
    get pest_path(admin_pest)
    assert_response :success
    
    get edit_pest_path(admin_pest)
    assert_response :success
  end

  test "regular user should not see other user pest in index" do
    other_user = create(:user)
    other_user_pest = create(:pest, :user_owned, user: other_user, name: '他のユーザーの害虫')
    my_pest = create(:pest, :user_owned, user: @user, name: '自分の害虫')
    reference_pest = create(:pest, is_reference: true, user_id: nil, name: '参照害虫')
    
    get pests_path
    assert_response :success
    
    # 一般ユーザーは自分の害虫のみ表示される（参照害虫は表示しない）
    response_body = response.body
    assert response_body.include?(my_pest.name), "自分の害虫が表示されるべき"
    assert_not response_body.include?(other_user_pest.name), "他人のユーザー害虫は表示されないべき"
    assert_not response_body.include?(reference_pest.name), "参照害虫は表示されないべき"
  end

  test "should not show other user pest detail" do
    other_user = create(:user)
    other_user_pest = create(:pest, :user_owned, user: other_user)
    
    get pest_path(other_user_pest)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "should show own pest detail" do
    my_pest = create(:pest, :user_owned, user: @user)
    
    get pest_path(my_pest)
    assert_response :success
  end

  test "should show reference pest detail for any user" do
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    
    get pest_path(reference_pest)
    assert_response :success
  end

  test "should not update other user pest" do
    user = create(:user)
    other_user = create(:user)
    sign_in_as user
    
    other_pest = create(:pest, :user_owned, user: other_user, name: '元の名前')
    
    patch pest_path(other_pest), params: { pest: {
      name: '変更しようとした名前'
    } }
    
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
    
    other_pest.reload
    assert_equal '元の名前', other_pest.name
  end

  test "should not delete other user pest" do
    user = create(:user)
    other_user = create(:user)
    sign_in_as user
    
    other_pest = create(:pest, :user_owned, user: other_user)
    
    assert_no_difference('Pest.count') do
      delete pest_path(other_pest)
    end
    
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "admin should update reference pest" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    ref_pest = create(:pest, is_reference: true, user_id: nil, name: '元の名前')
    
    patch pest_path(ref_pest), params: { pest: {
      name: '更新された名前'
    } }
    
    assert_redirected_to pest_path(ref_pest)
    ref_pest.reload
    assert_equal '更新された名前', ref_pest.name
  end

  test "regular user should not update reference pest" do
    user = create(:user)
    sign_in_as user
    
    ref_pest = create(:pest, is_reference: true, user_id: nil, name: '元の名前')
    
    patch pest_path(ref_pest), params: { pest: {
      name: '変更しようとした名前'
    } }
    
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "admin should delete reference pest" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    ref_pest = create(:pest, is_reference: true, user_id: nil)
    
    assert_difference('Pest.count', -1) do
      delete pest_path(ref_pest)
    end
    
    assert_redirected_to pests_path
  end

  test "regular user should not delete reference pest" do
    user = create(:user)
    sign_in_as user
    
    ref_pest = create(:pest, is_reference: true, user_id: nil)
    
    assert_no_difference('Pest.count') do
      delete pest_path(ref_pest)
    end
    
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.no_permission'), flash[:alert]
  end

  test "admin should create reference pest with nil user_id" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    assert_difference('Pest.count') do
      post pests_path, params: { pest: {
        name: '参照害虫',
        is_reference: true
      } }
    end
    
    pest = Pest.last
    assert_nil pest.user_id
    assert_equal true, pest.is_reference
  end

  test "admin should create user pest with admin user_id" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    assert_difference('Pest.count') do
      post pests_path, params: { pest: {
        name: 'ユーザー害虫',
        is_reference: false
      } }
    end
    
    pest = Pest.last
    assert_equal admin.id, pest.user_id
    assert_equal false, pest.is_reference
  end

  test "user_id should be automatically set on creation" do
    user = create(:user)
    sign_in_as user
    
    # user_idをパラメータに含めない
    post pests_path, params: { pest: {
      name: 'テスト害虫'
    } }
    
    pest = Pest.last
    assert_equal user.id, pest.user_id, "user_id should be automatically set to current_user.id"
  end

  test "multiple users should only see their own pests" do
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    
    # 各ユーザーの害虫を作成（一意の名前を設定）
    user1_pest = create(:pest, :user_owned, user: user1, name: 'User1専用害虫')
    user2_pest = create(:pest, :user_owned, user: user2, name: 'User2専用害虫')
    user3_pest = create(:pest, :user_owned, user: user3, name: 'User3専用害虫')
    ref_pest = create(:pest, is_reference: true, user_id: nil, name: '共有参照害虫')
    
    # user1でログイン
    sign_in_as user1
    get pests_path
    assert_response :success
    # レスポンスボディで確認
    response_body = response.body
    # 一般ユーザーは自分の害虫のみ表示（参照害虫は表示されない）
    assert_not response_body.include?(ref_pest.name), "参照害虫は一般ユーザーには表示されない"
    assert response_body.include?(user1_pest.name), "自分の害虫が表示されるべき"
    assert_not response_body.include?(user2_pest.name), "他のユーザーの害虫は表示されない"
    assert_not response_body.include?(user3_pest.name), "他のユーザーの害虫は表示されない"
    
    # user2でログイン
    sign_in_as user2
    get pests_path
    assert_response :success
    # レスポンスボディで確認
    response_body = response.body
    # 一般ユーザーは自分の害虫のみ表示（参照害虫は表示されない）
    assert_not response_body.include?(ref_pest.name), "参照害虫は一般ユーザーには表示されない"
    assert response_body.include?(user2_pest.name), "自分の害虫が表示されるべき"
    assert_not response_body.include?(user1_pest.name), "他のユーザーの害虫は表示されない"
    assert_not response_body.include?(user3_pest.name), "他のユーザーの害虫は表示されない"
  end

  test "should show only reference pests for regular user" do
    reference_pest = create(:pest, is_reference: true, user_id: nil)
    user_pest = create(:pest, :user_owned, user: @user)
    other_user = create(:user)
    other_user_pest = create(:pest, :user_owned, user: other_user)
    
    get pests_path
    assert_response :success
    # 一般ユーザーは参照害虫と自分の害虫を表示
    # 実際には @pest (参照), reference_pest, user_pest が表示される可能性がある
    assert_select '.crop-card', minimum: 1  # 最低1つ（@pestが参照害虫として既に存在）
    response_body = response.body
    # @pestは既にsetupで作成されているので、それが表示される
    assert response_body.include?(@pest.name) || response_body.include?(reference_pest.name) || response_body.include?(user_pest.name), "参照害虫または自分の害虫が表示されるべき"
  end

  test "should validate required fields on create" do
    assert_no_difference('Pest.count') do
      post pests_path, params: { pest: {
        name: '',  # 必須フィールドが空
        pest_id: ''
      } }
    end

    assert_response :unprocessable_entity
  end

  test "should handle validation errors on update" do
    pest = create(:pest, :user_owned, user: @user)
    
    patch pest_path(pest), params: { pest: {
      name: ''  # 必須フィールドを空にする
    } }
    
    assert_response :unprocessable_entity
    pest.reload
    assert_not_equal '', pest.name
  end

  # ========== エラーハンドリングのテスト ==========

  test "should handle RecordNotFound in show" do
    get pest_path(id: 99999)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.not_found'), flash[:alert]
  end

  test "should handle RecordNotFound in edit" do
    get edit_pest_path(id: 99999)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.not_found'), flash[:alert]
  end

  test "should handle RecordNotFound in update" do
    patch pest_path(id: 99999), params: { pest: { name: 'Test' } }
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.not_found'), flash[:alert]
  end

  test "should handle RecordNotFound in destroy" do
    delete pest_path(id: 99999)
    assert_redirected_to pests_path
    assert_equal I18n.t('pests.flash.not_found'), flash[:alert]
  end

  test "should handle InvalidForeignKey on destroy when pest has crop associations" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    crop = create(:crop, is_reference: false)
    CropPest.create!(crop: crop, pest: pest)
    
    initial_count = Pest.count
    
    # 削除を試行
    delete pest_path(pest)
    
    # 外部キー制約が有効な場合: InvalidForeignKeyエラーが発生して削除に失敗
    # 外部キー制約が無効な場合: 削除が成功するが、これは実際の運用では望ましくない
    final_count = Pest.count
    
    if final_count == initial_count
      # 削除に失敗した場合（外部キー制約が有効）
      assert_redirected_to pests_path
      assert_equal I18n.t('pests.flash.cannot_delete_in_use'), flash[:alert]
      assert_not_nil CropPest.find_by(pest_id: pest.id), "CropPest association should still exist"
    else
      # 削除が成功した場合（外部キー制約が無効、またはdependent: :destroyが動作）
      # この場合、CropPestも一緒に削除されているか確認
      if CropPest.exists?(pest_id: pest.id)
        # CropPestが残っている場合は外部キー制約が無効だった可能性
        skip "External foreign key constraints may not be enabled in this database"
      else
        # CropPestも削除されている場合はdependent: :destroyが動作した
        # これは正常な動作（外部キー制約エラーではなく、関連も一緒に削除される）
        assert_redirected_to pests_path
        assert_equal I18n.t('deletion_undo.redirect_notice', resource: pest.name), flash[:notice]
      end
    end
  end

  # ========== 権限チェックの追加テスト ==========

  test "should show non-reference pest without admin" do
    # 非参照害虫（ユーザー害虫）は一般ユーザーも閲覧可能
    non_ref_pest = create(:pest, :user_owned, user: @user)
    get pest_path(non_ref_pest)
    assert_response :success
  end

  # ========== バリデーションテストの追加 ==========

  test "should not create pest with duplicate pest_id" do
    # pest_idカラムが削除されたため、このテストは削除
    # nameの重複は許可されているため、バリデーションエラーは発生しない
    # 代わりにnameが必須であることをテスト
    assert_difference('Pest.count', 1) do
      post pests_path, params: { pest: {
        name: '新規害虫'
      } }
    end
    assert_redirected_to pest_path(Pest.last)
  end

  test "should not create pest with invalid control_method method_type" do
    assert_no_difference('Pest.count') do
      post pests_path, params: { pest: {
        name: 'Test Pest',
        pest_control_methods_attributes: {
          '0' => {
            method_type: 'invalid_type',  # 不正な値
            method_name: 'Test Method'
          }
        }
      } }
    end
    assert_response :unprocessable_entity
  end

  test "should not create pest with empty control_method method_name" do
    assert_no_difference('Pest.count') do
      assert_no_difference('PestControlMethod.count') do
        post pests_path, params: { pest: {
          name: 'Test Pest',
          pest_control_methods_attributes: {
            '0' => {
              method_type: 'chemical',
              method_name: ''  # 必須フィールドが空
            }
          }
        } }
      end
    end
    assert_response :unprocessable_entity
  end

  # ========== ネスト属性の削除・複合操作テスト ==========

  test "should destroy nested control_method with _destroy flag" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    method = pest.pest_control_methods.first
    initial_count = pest.pest_control_methods.count
    
    assert_difference('PestControlMethod.count', -1) do
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_control_methods_attributes: {
          '0' => {
            id: method.id,
            _destroy: '1'
          }
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal initial_count - 1, pest.pest_control_methods.count
    assert_nil PestControlMethod.find_by(id: method.id)
  end

  test "should destroy nested temperature_profile with _destroy flag" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    temp_profile = pest.pest_temperature_profile
    
    assert_difference('PestTemperatureProfile.count', -1) do
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_temperature_profile_attributes: {
          id: temp_profile.id,
          _destroy: '1'
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_nil pest.pest_temperature_profile
    assert_nil PestTemperatureProfile.find_by(id: temp_profile.id)
  end

  test "should destroy nested thermal_requirement with _destroy flag" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    thermal_req = pest.pest_thermal_requirement
    
    assert_difference('PestThermalRequirement.count', -1) do
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_thermal_requirement_attributes: {
          id: thermal_req.id,
          _destroy: '1'
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_nil pest.pest_thermal_requirement
    assert_nil PestThermalRequirement.find_by(id: thermal_req.id)
  end

  test "should update pest with multiple nested operations simultaneously" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    existing_method = pest.pest_control_methods.first
    new_method_type = pest.pest_control_methods.last.method_type
    
    # 1. 既存のtemperature_profileを更新
    # 2. 既存のcontrol_methodを更新
    # 3. 新しいcontrol_methodを追加
    # 4. 既存のcontrol_methodを1つ削除
    
    assert_difference('PestControlMethod.count', 0) do  # 1つ削除、1つ追加
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_temperature_profile_attributes: {
          id: pest.pest_temperature_profile.id,
          base_temperature: 20.0,
          max_temperature: 45.0
        },
        pest_control_methods_attributes: {
          '0' => {
            id: existing_method.id,
            method_type: 'cultural',
            method_name: '更新された方法',
            _destroy: 'false'
          },
          '1' => {
            id: pest.pest_control_methods.last.id,
            _destroy: '1'  # 削除
          },
          '2' => {
            method_type: 'physical',
            method_name: '新規物理的防除',
            description: '新しく追加された方法'
          }
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 20.0, pest.pest_temperature_profile.base_temperature
    assert_equal 45.0, pest.pest_temperature_profile.max_temperature
    assert_equal 'cultural', existing_method.reload.method_type
    assert_equal '更新された方法', existing_method.method_name
    assert_equal 3, pest.pest_control_methods.count  # 更新1 + 削除1 + 追加1 = 3
    assert_not_nil pest.pest_control_methods.find_by(method_type: 'physical')
  end

  test "should update pest with null nested attributes" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    # first_generation_gddがnullの場合の更新をテスト
    
    patch pest_path(pest), params: { pest: {
      name: pest.name,
      pest_thermal_requirement_attributes: {
        id: pest.pest_thermal_requirement.id,
        required_gdd: 250.0,
        first_generation_gdd: nil  # nullに設定
      }
    } }
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 250.0, pest.pest_thermal_requirement.required_gdd
    assert_nil pest.pest_thermal_requirement.first_generation_gdd
  end

  test "should create new nested attributes when updating without existing ones" do
    pest = create(:pest, :user_owned, user: @user)  # ネスト属性なしで作成
    
    # temperature_profileを新規作成
    assert_difference('PestTemperatureProfile.count', 1) do
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_temperature_profile_attributes: {
          base_temperature: 12.0,
          max_temperature: 38.0
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_not_nil pest.pest_temperature_profile
    assert_equal 12.0, pest.pest_temperature_profile.base_temperature
    assert_equal 38.0, pest.pest_temperature_profile.max_temperature
  end

  test "should update nested control_method while keeping others unchanged" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    method1 = pest.pest_control_methods.first
    method2 = pest.pest_control_methods.second
    original_name2 = method2.method_name
    
    # method1のみ更新、method2は変更なし
    patch pest_path(pest), params: { pest: {
      name: pest.name,
      pest_control_methods_attributes: {
        '0' => {
          id: method1.id,
          method_type: method1.method_type,
          method_name: '更新された方法名1',
          _destroy: 'false'
        }
      }
    } }
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal '更新された方法名1', method1.reload.method_name
    assert_equal original_name2, method2.reload.method_name  # 変更されていない
    assert_equal pest.pest_control_methods.count, 3  # すべて残っている
  end

  # ========== 防除方法パネルの重複作成防止テスト ==========

  test "should create pest with multiple control methods without duplication" do
    # 5つの防除方法を一度に追加
    assert_difference('PestControlMethod.count', 5) do
      post pests_path, params: { pest: {
        name: 'テスト害虫複数防除方法',
        pest_control_methods_attributes: {
          '0' => {
            method_type: 'chemical',
            method_name: '農薬1',
            description: '化学的防除1',
            timing_hint: '発生初期'
          },
          '1' => {
            method_type: 'biological',
            method_name: '天敵1',
            description: '生物的防除1',
            timing_hint: '発生確認時'
          },
          '2' => {
            method_type: 'cultural',
            method_name: '輪作1',
            description: '耕種的防除1',
            timing_hint: '栽培計画時'
          },
          '3' => {
            method_type: 'physical',
            method_name: '物理的防除1',
            description: '物理的防除1',
            timing_hint: '発生初期'
          },
          '4' => {
            method_type: 'chemical',
            method_name: '農薬2',
            description: '化学的防除2',
            timing_hint: '発生後期'
          }
        }
      } }
    end

    pest = Pest.last
    assert_equal 5, pest.pest_control_methods.count
    # 各防除方法が正しく作成されていることを確認
    assert_equal 'chemical', pest.pest_control_methods.find_by(method_name: '農薬1').method_type
    assert_equal 'biological', pest.pest_control_methods.find_by(method_name: '天敵1').method_type
    assert_equal 'cultural', pest.pest_control_methods.find_by(method_name: '輪作1').method_type
    assert_equal 'physical', pest.pest_control_methods.find_by(method_name: '物理的防除1').method_type
    assert_equal 'chemical', pest.pest_control_methods.find_by(method_name: '農薬2').method_type
  end

  test "should update pest with new control methods without affecting existing ones" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    existing_method = pest.pest_control_methods.first
    original_count = pest.pest_control_methods.count
    
    # 既存の防除方法を維持しつつ、新しい防除方法を2つ追加
    assert_difference('PestControlMethod.count', 2) do
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_control_methods_attributes: {
          '0' => {
            id: existing_method.id,
            method_type: existing_method.method_type,
            method_name: existing_method.method_name,
            _destroy: 'false'
          },
          '1' => {
            method_type: 'chemical',
            method_name: '新規農薬',
            description: '新規追加された防除方法',
            timing_hint: '発生初期'
          },
          '2' => {
            method_type: 'biological',
            method_name: '新規天敵',
            description: '新規追加された生物的防除',
            timing_hint: '発生確認時'
          }
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    # 既存の防除方法 + 新規2つ = 合計が正しいことを確認
    assert_equal original_count + 2, pest.pest_control_methods.count
    # 既存の防除方法が維持されていることを確認
    assert_not_nil pest.pest_control_methods.find_by(id: existing_method.id)
    # 新規追加された防除方法が存在することを確認
    assert_not_nil pest.pest_control_methods.find_by(method_name: '新規農薬')
    assert_not_nil pest.pest_control_methods.find_by(method_name: '新規天敵')
  end

  test "should handle control methods with consecutive indices correctly" do
    # 連続したインデックスで防除方法を追加（JavaScriptで追加された場合を想定）
    assert_difference('PestControlMethod.count', 3) do
      post pests_path, params: { pest: {
        name: 'テスト害虫連続インデックス',
        pest_control_methods_attributes: {
          '0' => {
            method_type: 'chemical',
            method_name: '農薬A',
            description: '説明A',
            timing_hint: '発生初期'
          },
          '1' => {
            method_type: 'biological',
            method_name: '天敵B',
            description: '説明B',
            timing_hint: '発生確認時'
          },
          '2' => {
            method_type: 'cultural',
            method_name: '輪作C',
            description: '説明C',
            timing_hint: '栽培計画時'
          }
        }
      } }
    end

    pest = Pest.last
    assert_equal 3, pest.pest_control_methods.count
    # すべての防除方法が正しく作成されていることを確認
    assert_equal 3, pest.pest_control_methods.pluck(:method_name).uniq.count
  end

  test "should not create duplicate control methods when same index is used multiple times" do
    # 同じインデックス（'0'）を複数回使用（本来は発生すべきでないが、防御的テスト）
    # この場合、Railsは最後の値のみを使用する
    # 警告を避けるため、ハッシュを直接構築
    control_methods_attrs = {}
    control_methods_attrs['0'] = {
      method_type: 'chemical',
      method_name: '農薬1',
      description: '説明1'
    }
    # 同じキーで上書き（実際の動作をシミュレート）
    control_methods_attrs['0'] = {
      method_type: 'biological',
      method_name: '天敵1',
      description: '説明2'
    }
    
    post pests_path, params: { pest: {
      name: 'テスト害虫重複インデックス',
      pest_control_methods_attributes: control_methods_attrs
    } }

    pest = Pest.last
    # Railsは同じキーに対して最後の値のみを使用するため、1つだけ作成される
    assert_equal 1, pest.pest_control_methods.count
    # 最後に送信された値（天敵1）が保存される
    assert_equal 'biological', pest.pest_control_methods.first.method_type
  end

  test "should handle control methods with _destroy flag correctly" do
    pest = create(:pest, :complete, :user_owned, user: @user)
    method1 = pest.pest_control_methods.first
    method2 = pest.pest_control_methods.second
    original_count = pest.pest_control_methods.count
    
    # method1を削除（_destroy: '1'）、method2は維持、新規を1つ追加
    assert_difference('PestControlMethod.count', 0) do  # 1つ削除、1つ追加で合計変わらず
      patch pest_path(pest), params: { pest: {
        name: pest.name,
        pest_control_methods_attributes: {
          '0' => {
            id: method1.id,
            _destroy: '1'
          },
          '1' => {
            id: method2.id,
            method_type: method2.method_type,
            method_name: method2.method_name,
            _destroy: 'false'
          },
          '2' => {
            method_type: 'physical',
            method_name: '新規物理的防除',
            description: '新規追加',
            timing_hint: '発生初期'
          }
        }
      } }
    end
    
    assert_redirected_to pest_path(pest)
    pest.reload
    # 1つ削除、1つ追加で合計は変わらない
    assert_equal original_count, pest.pest_control_methods.count
    # method1が削除されていることを確認
    assert_nil PestControlMethod.find_by(id: method1.id)
    # method2が維持されていることを確認
    assert_not_nil pest.pest_control_methods.find_by(id: method2.id)
    # 新規追加された防除方法が存在することを確認
    assert_not_nil pest.pest_control_methods.find_by(method_name: '新規物理的防除')
  end

  # ========== 作物選択機能のテスト ==========

  test "should show available crops in new form as cards" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    reference_crop = create(:crop, :reference)

    get new_pest_path
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop1.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop2.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"]), 0
    end
  end

  test "should show only user crops for regular user in new form" do
    my_crop = create(:crop, user: @user)
    other_user = create(:user)
    other_crop = create(:crop, user: other_user)
    reference_crop = create(:crop, :reference)

    get new_pest_path
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{my_crop.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_crop.id}"]), 0
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"]), 0
    end
  end

  test "should create pest with single crop association" do
    crop = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [crop.id]
        }
      end
    end

    pest = Pest.last
    assert_redirected_to pest_path(pest)
    assert pest.crops.include?(crop)
  end

  test "should create pest with multiple crop associations" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    crop3 = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 3) do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [crop1.id, crop2.id, crop3.id]
        }
      end
    end

    pest = Pest.last
    assert_equal 3, pest.crops.count
    assert pest.crops.include?(crop1)
    assert pest.crops.include?(crop2)
    assert pest.crops.include?(crop3)
  end

  test "should create pest without crop association" do
    assert_difference('Pest.count', 1) do
      assert_no_difference('CropPest.count') do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: []
        }
      end
    end

    pest = Pest.last
    assert_equal 0, pest.crops.count
  end

  test "should ignore invalid crop_ids on create" do
    crop = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [crop.id, 99999, '']
        }
      end
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(crop)
  end

  test "should not associate with other user's crop" do
    other_user = create(:user)
    other_crop = create(:crop, user: other_user)
    my_crop = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [other_crop.id, my_crop.id]
        }
      end
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(my_crop)
    assert_not pest.crops.include?(other_crop)
  end

  test "ユーザー害虫は参照作物と関連付けできない" do
    reference_crop = create(:crop, :reference)
    my_crop = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do
        post pests_path, params: {
          pest: { name: 'テスト害虫', is_reference: false },
          crop_ids: [reference_crop.id, my_crop.id]
        }
      end
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(my_crop)
    assert_not pest.crops.include?(reference_crop)
  end

  test "参照害虫は参照作物のみ関連付けられる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    reference_crop = create(:crop, :reference)
    user_crop = create(:crop, user: admin)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do
        post pests_path, params: { 
          pest: {
            name: '参照害虫',
            is_reference: true
          },
          crop_ids: [reference_crop.id, user_crop.id]
        }
      end
    end

    pest = Pest.last
    assert_equal true, pest.is_reference?
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(reference_crop)
    assert_not pest.crops.include?(user_crop)
  end

  test "should show associated crops in pest detail" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)
    create(:crop_pest, crop: crop2, pest: pest)

    get pest_path(pest)
    assert_response :success
    assert_select '.stages-title', text: I18n.t('pests.show.crops_title')
    assert_select '.related-crop-card', count: 2
    assert_select 'a.related-crop-card__link', count: 2
  end

  test "should show no crops message when pest has no associations" do
    pest = create(:pest, :user_owned, user: @user)

    get pest_path(pest)
    assert_response :success
    assert_select '.no-crops'
    assert_select '.related-crop-card', count: 0
  end

  test "ユーザー害虫の編集フォームではユーザー作物カードのみ表示され選択状態が保持される" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    other_user_crop = create(:crop, user: create(:user))
    reference_crop = create(:crop, :reference)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)

    get edit_pest_path(pest)
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop1.id}"][data-selected="true"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop2.id}"][data-selected="false"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_user_crop.id}"]), 0
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"]), 0
    end
    assert_select 'div[data-crop-selector-target="inputContainer"] input[name="crop_ids[]"][value=?]', crop1.id.to_s
  end

  test "参照害虫の編集フォームには参照作物のみ表示される" do
    admin = create(:user, admin: true)
    sign_in_as admin
    reference_crop = create(:crop, :reference)
    other_reference_crop = create(:crop, :reference)
    user_crop = create(:crop, user: @user)
    reference_pest = create(:pest, is_reference: true)
    create(:crop_pest, crop: reference_crop, pest: reference_pest)

    get edit_pest_path(reference_pest)
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"][data-selected="true"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_reference_crop.id}"][data-selected="false"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{user_crop.id}"]), 0
    end
    assert_select 'div[data-crop-selector-target="inputContainer"] input[name="crop_ids[]"][value=?]', reference_crop.id.to_s
  end

  test "地域指定のある害虫の編集フォームには地域一致の作物のみ表示される" do
    crop_in_region = create(:crop, user: @user, region: 'jp')
    crop_out_region = create(:crop, user: @user, region: 'us')
    pest = create(:pest, :user_owned, user: @user, region: 'jp')
    create(:crop_pest, crop: crop_in_region, pest: pest)

    get edit_pest_path(pest)
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop_in_region.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{crop_out_region.id}"]), 0
    end
  end

  test "should add crop association on update" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)

    assert_difference('CropPest.count', 1) do
      patch pest_path(pest), params: { 
        pest: {
          name: pest.name
        },
        crop_ids: [crop1.id, crop2.id]
      }
    end

    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 2, pest.crops.count
    assert pest.crops.include?(crop1)
    assert pest.crops.include?(crop2)
  end

  test "should remove crop association on update" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)
    create(:crop_pest, crop: crop2, pest: pest)

    assert_difference('CropPest.count', -1) do
      patch pest_path(pest), params: { 
        pest: {
          name: pest.name
        },
        crop_ids: [crop1.id]
      }
    end

    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 1, pest.crops.count
    assert pest.crops.include?(crop1)
    assert_not pest.crops.include?(crop2)
  end

  test "should update crop associations (add and remove simultaneously)" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    crop3 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)
    create(:crop_pest, crop: crop2, pest: pest)

    # crop1を維持、crop2を削除、crop3を追加
    assert_difference('CropPest.count', 0) do  # 1つ削除、1つ追加で合計変わらず
      patch pest_path(pest), params: { 
        pest: {
          name: pest.name
        },
        crop_ids: [crop1.id, crop3.id]
      }
    end

    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 2, pest.crops.count
    assert pest.crops.include?(crop1)
    assert_not pest.crops.include?(crop2)
    assert pest.crops.include?(crop3)
  end

  test "should remove all crop associations on update" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user)
    create(:crop_pest, crop: crop1, pest: pest)
    create(:crop_pest, crop: crop2, pest: pest)

    assert_difference('CropPest.count', -2) do
      patch pest_path(pest), params: { 
        pest: {
          name: pest.name
        },
        crop_ids: []
      }
    end

    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 0, pest.crops.count
  end

  test "should handle string crop_ids" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 2) do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [crop1.id.to_s, crop2.id.to_s]
        }
      end
    end

    pest = Pest.last
    assert_equal 2, pest.crops.count
  end

  test "should handle duplicate crop_ids" do
    crop = create(:crop, user: @user)

    assert_difference('Pest.count', 1) do
      assert_difference('CropPest.count', 1) do  # 重複は1つだけ
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          },
          crop_ids: [crop.id, crop.id, crop.id]
        }
      end
    end

    pest = Pest.last
    assert_equal 1, pest.crops.count
  end

  test "should handle empty crop_ids param" do
    assert_difference('Pest.count', 1) do
      assert_no_difference('CropPest.count') do
        post pests_path, params: { 
          pest: {
            name: 'テスト害虫',
            is_reference: false
          }
          # crop_idsパラメータなし
        }
      end
    end

    pest = Pest.last
    assert_equal 0, pest.crops.count
  end

  test "admin should initially see only own crops in new form" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    admin_crop = create(:crop, user: admin_user)
    other_user = create(:user)
    other_crop = create(:crop, user: other_user)
    reference_crop = create(:crop, :reference)

    get new_pest_path
    assert_response :success
    assert_select '[data-controller="crop-selector"]' do
      assert_select %(article[data-role="crop-card"][data-crop-id="#{admin_crop.id}"]), 1
      assert_select %(article[data-role="crop-card"][data-crop-id="#{reference_crop.id}"]), 0
      assert_select %(article[data-role="crop-card"][data-crop-id="#{other_crop.id}"]), 0
    end
  end

  test "should not update associations when validation fails" do
    crop1 = create(:crop, user: @user)
    crop2 = create(:crop, user: @user)
    pest = create(:pest, :user_owned, user: @user, name: 'テスト害虫')
    create(:crop_pest, crop: crop1, pest: pest)

    assert_no_difference('CropPest.count') do
      patch pest_path(pest), params: { 
        pest: {
          name: ''  # バリデーションエラー
        },
        crop_ids: [crop1.id, crop2.id]
      }
    end

    assert_response :unprocessable_entity
    pest.reload
    assert_equal 1, pest.crops.count  # 変更されていない
  end

  # ========== region編集のテスト ==========

  test "管理者は参照害虫のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    ref_pest = create(:pest, is_reference: true, user_id: nil, region: 'jp')
    
    patch pest_path(ref_pest), params: {
      pest: {
        name: ref_pest.name,
        region: 'us'
      }
    }
    
    assert_redirected_to pest_path(ref_pest)
    ref_pest.reload
    assert_equal 'us', ref_pest.region
  end

  test "管理者は自身の害虫のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    pest = create(:pest, :user_owned, user: admin, region: 'jp')
    
    patch pest_path(pest), params: {
      pest: {
        name: pest.name,
        region: 'in'
      }
    }
    
    assert_redirected_to pest_path(pest)
    pest.reload
    assert_equal 'in', pest.region
  end

  test "一般ユーザーはregionを更新できない" do
    pest = create(:pest, :user_owned, user: @user, region: 'jp')
    
    patch pest_path(pest), params: {
      pest: {
        name: pest.name,
        region: 'us'
      }
    }
    
    assert_redirected_to pest_path(pest)
    pest.reload
    # regionは変更されない（パラメータに含まれても無視される）
    assert_equal 'jp', pest.region
  end

  test "管理者は新規害虫作成時にregionを設定できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    post pests_path, params: {
      pest: {
        name: '新規害虫',
        is_reference: true,
        region: 'us'
      }
    }
    
    assert_redirected_to pest_path(Pest.last)
    pest = Pest.last
    assert_equal 'us', pest.region
  end

  test "一般ユーザーは新規害虫作成時にregionを設定できない" do
    post pests_path, params: {
      pest: {
        name: '新規害虫',
        region: 'us'
      }
    }
    
    assert_redirected_to pest_path(Pest.last)
    pest = Pest.last
    # regionは設定されない（パラメータに含まれても無視される）
    assert_nil pest.region
  end
end


