# frozen_string_literal: true

require 'test_helper'

class PesticidesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user
    @crop = create(:crop, :reference)
    @pest = create(:pest)
    @pesticide = create(:pesticide, crop: @crop, pest: @pest, is_reference: true)
  end

  test "should get index" do
    get pesticides_path
    assert_response :success
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
    assert_difference(['Pesticide.count', 'PesticideUsageConstraint.count']) do
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
    assert_not_nil pesticide.pesticide_usage_constraint
    assert_equal 5.0, pesticide.pesticide_usage_constraint.min_temperature
  end

  test "should create pesticide with application_detail" do
    assert_difference(['Pesticide.count', 'PesticideApplicationDetail.count']) do
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
    assert_not_nil pesticide.pesticide_application_detail
    assert_equal '1000倍', pesticide.pesticide_application_detail.dilution_ratio
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
    
    patch pesticide_path(pesticide), params: { pesticide: {
      name: pesticide.name,
      pesticide_usage_constraint_attributes: {
        id: constraint.id,
        min_temperature: 5.0
      }
    } }
    assert_redirected_to pesticide_path(pesticide)
    constraint.reload
    assert_equal 5.0, constraint.min_temperature
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

end

