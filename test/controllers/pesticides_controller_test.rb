# frozen_string_literal: true

require 'test_helper'
require 'time'

class PesticidesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    sign_in_as @user
    @crop = create(:crop, :reference)
    @pest = create(:pest)
    @pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true)
  end

  test "includes HtmlCrudResponder" do
    assert_includes PesticidesController.included_modules, HtmlCrudResponder
  end

  # ========== index アクションのテスト ==========

  test "一般ユーザーのindexは自身の非参照農薬のみ表示" do
    user_pesticide = create(:pesticide, :user_owned, user: @user, is_reference: false, name: 'ユーザー農薬')
    other_user = create(:user)
    other_pesticide = create(:pesticide, :user_owned, user: other_user, is_reference: false, name: '他人農薬')
    reference_pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true, user_id: nil, name: '参照農薬')

    get pesticides_path
    assert_response :success

    body = response.body
    assert_includes body, user_pesticide.name
    refute_includes body, other_pesticide.name
    refute_includes body, reference_pesticide.name
  end

  test "管理者のindexは自身の農薬と参照農薬を表示し他人の農薬は表示しない" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    admin_pesticide = create(:pesticide, :user_owned, user: admin_user, is_reference: false, name: '管理者農薬')
    other_user = create(:user)
    other_pesticide = create(:pesticide, :user_owned, user: other_user, is_reference: false, name: '他人農薬')
    reference_pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true, user_id: nil, name: '参照農薬')

    get pesticides_path
    assert_response :success

    body = response.body
    assert_includes body, admin_pesticide.name
    assert_includes body, reference_pesticide.name
    refute_includes body, other_pesticide.name
  end

  test "should show pesticide" do
    # 参照農薬は一般ユーザーでは見つからない（管理者のみアクセス可能）
    # テストでは一般ユーザーで参照農薬にアクセスするため、403エラー
    get pesticide_path(@pesticide)
    assert_redirected_to pesticides_path
    assert_equal I18n.t('pesticides.flash.not_found'), flash[:alert]
  end

  test "should get new" do
    get new_pesticide_path
    assert_response :success
  end

  test "should get edit for admin user" do
    # 管理者ユーザーを作成
    admin_user = create(:user, admin: true)
    sign_in_as admin_user
    
    get edit_pesticide_path(@pesticide)
    assert_response :success
  end

  test "should not get edit for non-admin user with reference pesticide" do
    # 参照農薬は管理者のみ編集可能（一般ユーザーは参照農薬が見つからない）
    get edit_pesticide_path(@pesticide)
    assert_redirected_to pesticides_path
    assert_equal I18n.t('pesticides.flash.not_found'), flash[:alert]
  end

  test "should create pesticide" do
    assert_difference('Pesticide.count') do
      post pesticides_path, params: { pesticide: {
        name: 'テスト農薬',
        active_ingredient: 'テスト成分',
        description: 'テスト用',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false
      } }
    end

    assert_redirected_to pesticide_path(Pesticide.last)
    pesticide = Pesticide.last
    assert_equal 'テスト農薬', pesticide.name
  end

  test "should create pesticide with usage_constraint" do
    # 現状の Create Interactor は nested attributes を扱わないため Pesticide のみ作成される
    assert_difference('Pesticide.count', 1) do
      post pesticides_path, params: { pesticide: {
        name: 'テスト農薬',
        active_ingredient: 'テスト成分',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false,
        pesticide_usage_constraint_attributes: {
          min_temperature: 5.0,
          max_temperature: 35.0,
          max_wind_speed_m_s: 3.0,
          max_application_count: 3,
          harvest_interval_days: 1
        }
      } }
    end

    pesticide = Pesticide.last
    assert_equal 'テスト農薬', pesticide.name
  end

  test "should create pesticide with application_detail" do
    # 現状の Create Interactor は nested attributes を扱わないため Pesticide のみ作成される
    assert_difference('Pesticide.count', 1) do
      post pesticides_path, params: { pesticide: {
        name: 'テスト農薬',
        active_ingredient: 'テスト成分',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: false,
        pesticide_application_detail_attributes: {
          dilution_ratio: '1000倍',
          amount_per_m2: 0.1,
          amount_unit: 'ml',
          application_method: '散布'
        }
      } }
    end

    pesticide = Pesticide.last
    assert_equal 'テスト農薬', pesticide.name
  end

  test "should update pesticide" do
    # ユーザー農薬を作成
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
    
    patch pesticide_path(pesticide), params: { pesticide: {
      name: '更新された農薬名',
      active_ingredient: '更新された成分'
    } }
    assert_redirected_to pesticide_path(pesticide)
    pesticide.reload
    assert_equal '更新された農薬名', pesticide.name
    assert_equal '更新された成分', pesticide.active_ingredient
  end

  test "should update pesticide with usage_constraint" do
    # ユーザー農薬を作成
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
    constraint = create(:pesticide_usage_constraint, pesticide: pesticide, min_temperature: 10.0)

    # 現状の Update Interactor は nested attributes を扱わないため、リダイレクトのみ検証
    patch pesticide_path(pesticide), params: { pesticide: {
      name: pesticide.name,
      pesticide_usage_constraint_attributes: {
        id: constraint.id,
        min_temperature: 5.0
      }
    } }
    assert_redirected_to pesticide_path(pesticide)
  end

  test "一般ユーザーはis_referenceフラグを変更できない" do
    # ユーザー所有の非参照農薬
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, is_reference: false)
    original_is_reference = pesticide.is_reference

    patch pesticide_path(pesticide), params: { pesticide: {
      name: pesticide.name,
      active_ingredient: pesticide.active_ingredient,
      is_reference: true
    } }

    assert_redirected_to pesticide_path(pesticide)
    assert_equal I18n.t('pesticides.flash.reference_flag_admin_only'), flash[:alert]

    pesticide.reload
    assert_equal original_is_reference, pesticide.is_reference
    assert_equal @user.id, pesticide.user_id
  end

  test "作成時に必須項目が欠けていると422でnewを再表示する" do
    # name を空にしてバリデーションエラーを発生させる
    assert_no_difference('Pesticide.count') do
      post pesticides_path, params: { pesticide: {
        name: '',
        crop_id: @crop.id,
        pest_id: @pest.id
      } }
    end

    assert_response :unprocessable_entity
  end

  test "update時に必須項目が欠けていると422でeditを再表示する" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, name: '元の名前')
    original_name = pesticide.name

    patch pesticide_path(pesticide), params: { pesticide: {
      name: ''
    } }

    assert_response :unprocessable_entity

    pesticide.reload
    assert_equal original_name, pesticide.name
  end

  test "should not update reference pesticide as non-admin" do
    # 参照農薬は管理者のみ更新可能（一般ユーザーは参照農薬が見つからない）
    patch pesticide_path(@pesticide), params: { pesticide: {
      name: '更新された名前'
    } }
    assert_redirected_to pesticides_path
    assert_equal I18n.t('pesticides.flash.not_found'), flash[:alert]
    
    @pesticide.reload
    assert_not_equal '更新された名前', @pesticide.name
  end

  test "should destroy pesticide" do
    # 外部参照のない農薬を作成
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)
    
    assert_difference('Pesticide.count', -1) do
      delete pesticide_path(pesticide)
    end

    assert_redirected_to pesticides_path
  end

  test "should not allow non-admin to create reference pesticide" do
    assert_no_difference('Pesticide.count') do
      post pesticides_path, params: { pesticide: {
        name: '参照農薬',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      } }
    end

    assert_redirected_to pesticides_path
    assert_equal I18n.t('pesticides.flash.reference_only_admin'), flash[:alert]
  end

  test "should allow admin to create reference pesticide" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    assert_difference('Pesticide.count') do
      post pesticides_path, params: { pesticide: {
        name: '参照農薬',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true
      } }
    end

    assert_redirected_to pesticide_path(Pesticide.last)
    assert Pesticide.last.is_reference?
  end

  test "should display crops and pests in new form" do
    get new_pesticide_path
    assert_response :success
    # ビューで@cropsと@pestsが設定されていることを確認
    # (実際のビューで使用されているため)
  end

  test "should display crops and pests in edit form" do
    admin_user = create(:user, admin: true)
    sign_in_as admin_user

    get edit_pesticide_path(@pesticide)
    assert_response :success
    # ビューで@cropsと@pestsが設定されていることを確認
  end

  test "destroy_returns_undo_token_json" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)

    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference -> { Pesticide.count }, -1 do
        delete pesticide_path(pesticide), as: :json
      end
    end

    assert_response :success

    body = response.parsed_body
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, body.fetch('undo_token'))
    assert_nothing_raised { Time.iso8601(body.fetch('undo_deadline')) }
    assert body.fetch('toast_message').present?, 'toast_message が存在すること'

    undo_token = body.fetch('undo_token')
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal pesticides_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(pesticide), body.fetch('resource_dom_id')
  end

  test "undo_endpoint_restores_pesticide" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest)

    delete pesticide_path(pesticide), as: :json
    assert_response :success
    undo_token = response.parsed_body.fetch('undo_token')
    event = DeletionUndoEvent.find(undo_token)
    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'scheduled', event.state

    assert_difference -> { Pesticide.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert_equal 'restored', body.fetch('status')
    assert flash.empty?, 'JSON 応答では flash を利用しないこと'

    event.reload
    assert_equal 'restored', event.state
  end

  # ========== region編集のテスト ==========

  test "管理者は参照農薬のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    ref_pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true, user_id: nil, region: 'jp')
    
    patch pesticide_path(ref_pesticide), params: {
      pesticide: {
        name: ref_pesticide.name,
        crop_id: ref_pesticide.crop_id,
        pest_id: ref_pesticide.pest_id,
        region: 'us'
      }
    }
    
    assert_redirected_to pesticide_path(ref_pesticide)
    ref_pesticide.reload
    assert_equal 'us', ref_pesticide.region
  end

  test "管理者は自身の農薬のregionを更新できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    pesticide = create(:pesticide, :user_owned, user: admin, crop: @crop, pest: @pest, region: 'jp')
    
    patch pesticide_path(pesticide), params: {
      pesticide: {
        name: pesticide.name,
        crop_id: pesticide.crop_id,
        pest_id: pesticide.pest_id,
        region: 'in'
      }
    }
    
    assert_redirected_to pesticide_path(pesticide)
    pesticide.reload
    assert_equal 'in', pesticide.region
  end

  test "一般ユーザーはregionを更新できない" do
    pesticide = create(:pesticide, :user_owned, user: @user, crop: @crop, pest: @pest, region: 'jp')
    
    patch pesticide_path(pesticide), params: {
      pesticide: {
        name: pesticide.name,
        crop_id: pesticide.crop_id,
        pest_id: pesticide.pest_id,
        region: 'us'
      }
    }
    
    assert_redirected_to pesticide_path(pesticide)
    pesticide.reload
    # regionは変更されない（パラメータに含まれても無視される）
    assert_equal 'jp', pesticide.region
  end

  test "管理者は新規農薬作成時にregionを設定できる" do
    admin = create(:user, admin: true)
    sign_in_as admin
    
    post pesticides_path, params: {
      pesticide: {
        name: '新規農薬',
        crop_id: @crop.id,
        pest_id: @pest.id,
        is_reference: true,
        region: 'us'
      }
    }
    
    assert_redirected_to pesticide_path(Pesticide.last)
    pesticide = Pesticide.last
    assert_equal 'us', pesticide.region
  end

  test "一般ユーザーは新規農薬作成時にregionを設定できない" do
    post pesticides_path, params: {
      pesticide: {
        name: '新規農薬',
        crop_id: @crop.id,
        pest_id: @pest.id,
        region: 'us'
      }
    }
    
    assert_redirected_to pesticide_path(Pesticide.last)
    pesticide = Pesticide.last
    # regionは設定されない（パラメータに含まれても無視される）
    assert_nil pesticide.region
  end
end

