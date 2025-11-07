# frozen_string_literal: true

require 'test_helper'

module Crops
  class PestsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = create(:user)
      @crop = create(:crop, user: @user)
      sign_in_as @user
    end

    # ========== 一覧表示テスト ==========

    test "should get index with associated pests" do
      pest1 = create(:pest, is_reference: true)
      pest2 = create(:pest, is_reference: true)
      create(:crop_pest, crop: @crop, pest: pest1)
      create(:crop_pest, crop: @crop, pest: pest2)

      get crop_pests_path(@crop)
      assert_response :success
      assert_select '.page-title' do |elements|
        assert_select 'a', text: @crop.name
        assert_includes elements.first.text, I18n.t('crops.pests.index.title')
      end
      assert_select '.crop-card', count: 2
    end

    test "should get index with no pests" do
      get crop_pests_path(@crop)
      assert_response :success
      assert_select '.empty-state'
      assert_select '.crop-card', count: 0
    end

    test "should redirect when accessing other user's crop" do
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)

      get crop_pests_path(other_crop)
      assert_redirected_to crops_path
      assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
    end

    test "admin should not access other user's crop" do
      admin_user = create(:user, admin: true)
      sign_in_as admin_user
      
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)

      get crop_pests_path(other_crop)
      assert_redirected_to crops_path
      assert_equal I18n.t('crops.flash.no_permission'), flash[:alert]
    end

    test "admin should see only reference pests and own pests in crop pests index" do
      admin_user = create(:user, admin: true)
      sign_in_as admin_user
      admin_crop = create(:crop, user: admin_user)

      reference_pest = create(:pest, is_reference: true, user_id: nil, name: '参照害虫A')
      admin_pest = create(:pest, :user_owned, user: admin_user, name: '管理者害虫B')
      other_user = create(:user)
      other_user_pest = create(:pest, :user_owned, user: other_user, name: '他人害虫C')

      # 害虫を作物に関連付け
      create(:crop_pest, crop: admin_crop, pest: reference_pest)
      create(:crop_pest, crop: admin_crop, pest: admin_pest)
      create(:crop_pest, crop: admin_crop, pest: other_user_pest)

      get crop_pests_path(admin_crop)
      assert_response :success

      # 管理者は参照害虫と自分の害虫のみ表示される
      assert_select '.crop-card .crop-name', text: reference_pest.name, count: 1
      assert_select '.crop-card .crop-name', text: admin_pest.name, count: 1
      assert_select '.crop-card .crop-name', text: other_user_pest.name, count: 0
    end

    test "admin should not access other user's pest through crop" do
      admin_user = create(:user, admin: true)
      sign_in_as admin_user
      admin_crop = create(:crop, user: admin_user)
      
      other_user = create(:user)
      other_crop = create(:crop, user: other_user)
      other_user_pest = create(:pest, :user_owned, user: other_user)
      create(:crop_pest, crop: other_crop, pest: other_user_pest)
      
      # 他人の作物の害虫管理画面にアクセス試行（まず作物へのアクセスが拒否される）
      get crop_pests_path(other_crop)
      assert_redirected_to crops_path
      
      # もし何らかの方法で害虫にアクセスしようとした場合
      get crop_pest_path(admin_crop, other_user_pest)
      # 害虫が作物に関連付けられていないので、リダイレクトされる
      assert_redirected_to crop_pests_path(admin_crop)
    end

    test "should access reference crop" do
      reference_crop = create(:crop, :reference)

      get crop_pests_path(reference_crop)
      assert_response :success
    end

    test "should redirect when crop not found" do
      get crop_pests_path(crop_id: 99999)
      assert_redirected_to crops_path
      assert_equal I18n.t('crops.flash.not_found'), flash[:alert]
    end

    # ========== 詳細表示テスト ==========

    test "should show pest associated with crop" do
      pest = create(:pest, is_reference: true)
      create(:crop_pest, crop: @crop, pest: pest)

      get crop_pest_path(@crop, pest)
      assert_response :success
      assert_select '.crop-detail-title' do |elements|
        assert_select 'a', text: @crop.name
        assert_includes elements.first.text, pest.name
      end
    end

    test "should redirect when pest not associated with crop" do
      pest = create(:pest, is_reference: true)
      other_crop = create(:crop, user: @user)
      create(:crop_pest, crop: other_crop, pest: pest)

      get crop_pest_path(@crop, pest)
      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.not_found'), flash[:alert]
    end

    test "should redirect when pest not found" do
      get crop_pest_path(@crop, id: 99999)
      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.not_found'), flash[:alert]
    end

    # ========== 新規作成画面テスト ==========

    test "should get new" do
      create(:pest, is_reference: true)

      get new_crop_pest_path(@crop)
      assert_response :success
      assert_select 'form'
      assert_select 'select[name="pest_id"]'
    end

    test "should show unassociated pests in new form" do
      associated_pest = create(:pest, is_reference: true)
      unassociated_pest1 = create(:pest, is_reference: true)
      unassociated_pest2 = create(:pest, is_reference: true)
      create(:crop_pest, crop: @crop, pest: associated_pest)

      get new_crop_pest_path(@crop)
      assert_response :success

      assert_select 'select[name="pest_id"] option[value=?]', unassociated_pest1.id.to_s
      assert_select 'select[name="pest_id"] option[value=?]', unassociated_pest2.id.to_s
      assert_select 'select[name="pest_id"] option[value=?]', associated_pest.id.to_s, count: 0
    end

    # ========== 既存害虫の関連付けテスト ==========

    test "should associate existing pest with crop" do
      pest = create(:pest, is_reference: true)

      assert_difference('CropPest.count', 1) do
        post crop_pests_path(@crop), params: { pest_id: pest.id }
      end

      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.associated'), flash[:notice]
      assert @crop.pests.include?(pest)
    end

    test "should not duplicate association when pest already associated" do
      pest = create(:pest, is_reference: true)
      create(:crop_pest, crop: @crop, pest: pest)

      assert_no_difference('CropPest.count') do
        post crop_pests_path(@crop), params: { pest_id: pest.id }
      end

      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.already_associated'), flash[:alert]
    end

    test "should handle invalid pest_id" do
      assert_no_difference('CropPest.count') do
        post crop_pests_path(@crop), params: { pest_id: 99999 }
      end

      assert_redirected_to crop_pests_path(@crop)
    end

    # ========== 新規害虫の作成と関連付けテスト ==========

    test "should create new pest and associate with crop" do
      assert_difference('Pest.count', 1) do
        assert_difference('CropPest.count', 1) do
          post crop_pests_path(@crop), params: { pest: {
            name: '新規害虫',
            name_scientific: 'New Pest',
            family: '新規科',
            is_reference: false
          } }
        end
      end

      pest = Pest.last
      assert_redirected_to crop_pest_path(@crop, pest)
      assert_equal I18n.t('crops.pests.flash.created'), flash[:notice]
      assert @crop.pests.include?(pest)
      assert_equal false, pest.is_reference
      assert_equal @user.id, pest.user_id
    end

    test "should not create pest with invalid data" do
      assert_no_difference('Pest.count') do
        assert_no_difference('CropPest.count') do
          post crop_pests_path(@crop), params: { pest: {
            name: '',  # 必須フィールドが空
            is_reference: false
          } }
        end
      end

      assert_response :unprocessable_entity
    end

    test "should not allow regular user to create reference pest" do
      assert_no_difference('Pest.count') do
        post crop_pests_path(@crop), params: { pest: {
          name: '参照害虫',
          is_reference: true
        } }
      end

      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.reference_only_admin'), flash[:alert]
    end

    test "admin should create reference pest" do
      admin_user = create(:user, admin: true)
      sign_in_as admin_user
      admin_crop = create(:crop, user: admin_user)

      assert_difference('Pest.count', 1) do
        assert_difference('CropPest.count', 1) do
          post crop_pests_path(admin_crop), params: { pest: {
            name: '参照害虫',
            is_reference: true
          } }
        end
      end

      pest = Pest.last
      assert_equal true, pest.is_reference
      assert_nil pest.user_id
    end

    # ========== 編集テスト ==========

    test "should get edit for associated pest" do
      pest = create(:pest, is_reference: true)
      create(:crop_pest, crop: @crop, pest: pest)

      get edit_crop_pest_path(@crop, pest)
      assert_response :success
      assert_select 'form'
    end

    test "should redirect when editing pest not associated with crop" do
      pest = create(:pest, is_reference: true)
      other_crop = create(:crop, user: @user)
      create(:crop_pest, crop: other_crop, pest: pest)

      get edit_crop_pest_path(@crop, pest)
      assert_redirected_to crop_pests_path(@crop)
      assert_equal I18n.t('crops.pests.flash.not_found'), flash[:alert]
    end

    # ========== 更新テスト ==========

    test "should update pest" do
      pest = create(:pest, is_reference: true, name: '元の名前')
      create(:crop_pest, crop: @crop, pest: pest)

      patch crop_pest_path(@crop, pest), params: { pest: {
        name: '更新後の名前',
        description: '更新された説明'
      } }

      assert_redirected_to crop_pest_path(@crop, pest)
      assert_equal I18n.t('crops.pests.flash.updated'), flash[:notice]
      pest.reload
      assert_equal '更新後の名前', pest.name
      assert_equal '更新された説明', pest.description
    end

    test "should not allow regular user to change is_reference flag" do
      pest = create(:pest, :user_owned, user: @user, name: 'ユーザー害虫')
      create(:crop_pest, crop: @crop, pest: pest)

      patch crop_pest_path(@crop, pest), params: { pest: {
        name: pest.name,
        is_reference: true
      } }

      assert_redirected_to crop_pest_path(@crop, pest)
      assert_equal I18n.t('crops.pests.flash.reference_flag_admin_only'), flash[:alert]
      pest.reload
      assert_equal false, pest.is_reference
    end

    test "should handle validation errors on update" do
      pest = create(:pest, is_reference: true, name: 'テスト害虫')
      create(:crop_pest, crop: @crop, pest: pest)

      patch crop_pest_path(@crop, pest), params: { pest: {
        name: ''  # 必須フィールドを空にする
      } }

      assert_response :unprocessable_entity
      pest.reload
      assert_not_equal '', pest.name
    end
  end
end

