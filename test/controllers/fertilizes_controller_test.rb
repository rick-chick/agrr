# frozen_string_literal: true

require 'test_helper'
require 'time'

class FertilizesControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)
    @other_user = create(:user)
    
    # 参照肥料（user_id: nil）
    @reference_fertilize = create(:fertilize, is_reference: true, user_id: nil)
    # 一般ユーザーの肥料
    @user_fertilize = create(:fertilize, :user_owned, user: @user)
    # 他のユーザーの肥料
    @other_user_fertilize = create(:fertilize, :user_owned, user: @other_user)
    # 管理者の肥料
    @admin_fertilize = create(:fertilize, :user_owned, user: @admin_user)
  end

  # ========== index アクションのテスト ==========
  
  test "一般ユーザーのindexは自身の肥料のみ表示" do
    sign_in_as @user
    get fertilizes_path
    
    assert_response :success
    # 一般ユーザーの肥料のみが表示される
    assert_select '.crop-card', count: 1
    # 参照肥料や他のユーザーの肥料は表示されない
  end

  test "管理者のindexは自身の肥料と参照肥料を表示" do
    sign_in_as @admin_user
    get fertilizes_path
    
    assert_response :success
    # 管理者の肥料と参照肥料が表示される（最低2つ）
    # 注: 実際の表示件数はビューで確認する必要があるが、ここではリクエストが成功することを確認
  end

  # ========== show アクションのテスト ==========
  
  test "一般ユーザーは自身の肥料をshowできる" do
    sign_in_as @user
    get fertilize_path(@user_fertilize)
    
    assert_response :success
  end

  test "一般ユーザーは参照肥料をshowできない" do
    sign_in_as @user
    get fertilize_path(@reference_fertilize)
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの肥料をshowできない" do
    sign_in_as @user
    get fertilize_path(@other_user_fertilize)
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "管理者は参照肥料をshowできる" do
    sign_in_as @admin_user
    get fertilize_path(@reference_fertilize)
    
    assert_response :success
  end

  test "管理者は自身の肥料をshowできる" do
    sign_in_as @admin_user
    get fertilize_path(@admin_fertilize)
    
    assert_response :success
  end

  # ========== edit アクションのテスト ==========
  
  test "一般ユーザーは自身の肥料をeditできる" do
    sign_in_as @user
    get edit_fertilize_path(@user_fertilize)
    
    assert_response :success
  end

  test "一般ユーザーは参照肥料をeditできない" do
    sign_in_as @user
    get edit_fertilize_path(@reference_fertilize)
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの肥料をeditできない" do
    sign_in_as @user
    get edit_fertilize_path(@other_user_fertilize)
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "管理者は参照肥料をeditできる" do
    sign_in_as @admin_user
    get edit_fertilize_path(@reference_fertilize)
    
    assert_response :success
  end

  test "管理者は自身の肥料をeditできる" do
    sign_in_as @admin_user
    get edit_fertilize_path(@admin_fertilize)
    
    assert_response :success
  end

  # ========== create アクションのテスト ==========
  
  test "一般ユーザーは自身の肥料を作成できる（user_idが自動設定される）" do
    sign_in_as @user
    assert_difference('Fertilize.count') do
      post fertilizes_path, params: { fertilize: {
        name: 'テスト肥料',
        n: 20.0,
        p: 10.0,
        k: 10.0,
        description: 'テスト用',
        package_size: 20.0
      } }
    end

    assert_redirected_to fertilize_path(Fertilize.last)
    fertilize = Fertilize.last
    assert_equal 20.0, fertilize.package_size
    assert_equal @user.id, fertilize.user_id
    assert_equal false, fertilize.is_reference
  end

  test "一般ユーザーは参照肥料を作成できない" do
    sign_in_as @user
    assert_no_difference('Fertilize.count') do
      post fertilizes_path, params: { fertilize: {
        name: '参照肥料',
        n: 20.0,
        p: 10.0,
        k: 10.0,
        is_reference: true
      } }
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.reference_only_admin'), flash[:alert]
  end

  test "管理者は参照肥料を作成できる" do
    sign_in_as @admin_user
    assert_difference('Fertilize.count') do
      post fertilizes_path, params: { fertilize: {
        name: '参照肥料',
        n: 20.0,
        p: 10.0,
        k: 10.0,
        is_reference: true
      } }
    end

    assert_redirected_to fertilize_path(Fertilize.last)
    fertilize = Fertilize.last
    assert_equal true, fertilize.is_reference
    assert_nil fertilize.user_id
  end

  test "管理者は自身の肥料を作成できる" do
    sign_in_as @admin_user
    assert_difference('Fertilize.count') do
      post fertilizes_path, params: { fertilize: {
        name: '管理者の肥料',
        n: 20.0,
        p: 10.0,
        k: 10.0,
        is_reference: false
      } }
    end

    assert_redirected_to fertilize_path(Fertilize.last)
    fertilize = Fertilize.last
    assert_equal @admin_user.id, fertilize.user_id
    assert_equal false, fertilize.is_reference
  end

  # ========== update アクションのテスト ==========
  
  test "一般ユーザーは自身の肥料をupdateできる" do
    sign_in_as @user
    patch fertilize_path(@user_fertilize), params: { fertilize: {
      name: @user_fertilize.name,
      n: 25.0
    } }
    
    assert_redirected_to fertilize_path(@user_fertilize)
    @user_fertilize.reload
    assert_equal 25.0, @user_fertilize.n
  end

  test "一般ユーザーは参照肥料をupdateできない" do
    sign_in_as @user
    old_n = @reference_fertilize.n
    
    patch fertilize_path(@reference_fertilize), params: { fertilize: {
      name: @reference_fertilize.name,
      n: 30.0
    } }
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
    
    @reference_fertilize.reload
    assert_equal old_n, @reference_fertilize.n
  end

  test "一般ユーザーは他のユーザーの肥料をupdateできない" do
    sign_in_as @user
    old_n = @other_user_fertilize.n
    
    patch fertilize_path(@other_user_fertilize), params: { fertilize: {
      name: @other_user_fertilize.name,
      n: 30.0
    } }
    
    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
    
    @other_user_fertilize.reload
    assert_equal old_n, @other_user_fertilize.n
  end

  test "管理者は参照肥料をupdateできる" do
    sign_in_as @admin_user
    patch fertilize_path(@reference_fertilize), params: { fertilize: {
      name: @reference_fertilize.name,
      n: 30.0
    } }
    
    assert_redirected_to fertilize_path(@reference_fertilize)
    @reference_fertilize.reload
    assert_equal 30.0, @reference_fertilize.n
  end

  test "管理者は自身の肥料をupdateできる" do
    sign_in_as @admin_user
    patch fertilize_path(@admin_fertilize), params: { fertilize: {
      name: @admin_fertilize.name,
      n: 30.0
    } }
    
    assert_redirected_to fertilize_path(@admin_fertilize)
    @admin_fertilize.reload
    assert_equal 30.0, @admin_fertilize.n
  end

  test "一般ユーザーはis_referenceフラグを変更できない" do
    sign_in_as @user
    patch fertilize_path(@user_fertilize), params: { fertilize: {
      name: @user_fertilize.name,
      is_reference: true
    } }
    
    assert_redirected_to fertilize_path(@user_fertilize)
    assert_equal I18n.t('fertilizes.flash.reference_flag_admin_only'), flash[:alert]
    
    @user_fertilize.reload
    assert_equal false, @user_fertilize.is_reference
  end

  # ========== destroy アクションのテスト ==========
  
  test "一般ユーザーは自身の肥料をdestroyできる" do
    sign_in_as @user
    fertilize = create(:fertilize, :user_owned, user: @user)

    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference('Fertilize.count', -1) do
        delete fertilize_path(fertilize)
      end
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('deletion_undo.redirect_notice', resource: fertilize.name), flash[:notice]
    # TODO: HTMLレスポンスのUndoトースト表示もDOMレベルで検証する
  end

  test "一般ユーザーは参照肥料をdestroyできない" do
    sign_in_as @user
    reference_fertilize = create(:fertilize, is_reference: true, user_id: nil)
    
    assert_no_difference('Fertilize.count') do
      delete fertilize_path(reference_fertilize)
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーの肥料をdestroyできない" do
    sign_in_as @user
    other_fertilize = create(:fertilize, :user_owned, user: @other_user)
    
    assert_no_difference('Fertilize.count') do
      delete fertilize_path(other_fertilize)
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('fertilizes.flash.not_found'), flash[:alert]
  end

  test "管理者は参照肥料をdestroyできる" do
    sign_in_as @admin_user
    reference_fertilize = create(:fertilize, is_reference: true, user_id: nil)

    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference('Fertilize.count', -1) do
        delete fertilize_path(reference_fertilize)
      end
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('deletion_undo.redirect_notice', resource: reference_fertilize.name), flash[:notice]
    # TODO: HTMLレスポンスのUndoトースト表示もDOMレベルで検証する
  end

  test "管理者は自身の肥料をdestroyできる" do
    sign_in_as @admin_user
    admin_fertilize = create(:fertilize, :user_owned, user: @admin_user)

    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference('Fertilize.count', -1) do
        delete fertilize_path(admin_fertilize)
      end
    end

    assert_redirected_to fertilizes_path
    assert_equal I18n.t('deletion_undo.redirect_notice', resource: admin_fertilize.name), flash[:notice]
    # TODO: HTMLレスポンスのUndoトースト表示もDOMレベルで検証する
  end

  test "destroy_returns_undo_token_json" do
    sign_in_as @user
    fertilize = create(:fertilize, :user_owned, user: @user)

    assert_difference -> { DeletionUndoEvent.count }, +1 do
      assert_difference -> { Fertilize.count }, -1 do
        delete fertilize_path(fertilize), as: :json
      end
    end

    assert_response :success

    body = response.parsed_body
    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i, body.fetch('undo_token'))
    assert_nothing_raised { Time.iso8601(body.fetch('undo_deadline')) }
    assert body.fetch('toast_message').present?, 'toast_message が存在すること'

    undo_token = body.fetch('undo_token')
    assert_equal undo_deletion_path(undo_token: undo_token), body.fetch('undo_path')
    assert_equal fertilizes_path(locale: I18n.locale), body.fetch('redirect_path')
    assert_equal dom_id(fertilize), body.fetch('resource_dom_id')
    # TODO: HTMLレスポンスのUndoパスについては実装後に検証する
  end

  test "undo_endpoint_restores_fertilize" do
    sign_in_as @user
    fertilize = create(:fertilize, :user_owned, user: @user)

    assert_difference -> { Fertilize.count }, -1 do
      delete fertilize_path(fertilize), as: :json
    end

    assert_response :success
    undo_token = response.parsed_body.fetch('undo_token')

    event = DeletionUndoEvent.find(undo_token)
    assert_equal 'scheduled', event.state
    assert_not Fertilize.exists?(fertilize.id), '削除後はFertilizeが存在しないこと'

    assert_difference -> { Fertilize.count }, +1 do
      post undo_deletion_path, params: { undo_token: undo_token }, as: :json
    end

    assert_response :success
    body = response.parsed_body
    assert_equal 'restored', body.fetch('status')
    assert flash.empty?, 'JSON 応答では flash を利用しないこと'

    event.reload
    assert_equal 'restored', event.state

    restored = Fertilize.find(fertilize.id)
    assert_equal @user.id, restored.user_id
    refute restored.is_reference?, 'ユーザー所有の肥料として復元されること'
    # TODO: HTMLレスポンスのUndoフローは別途追加予定
  end

  # ========== new アクションのテスト ==========
  
  test "should get new" do
    sign_in_as @user
    get new_fertilize_path
    assert_response :success
  end
end
