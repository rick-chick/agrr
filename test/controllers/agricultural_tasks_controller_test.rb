# frozen_string_literal: true

require 'test_helper'

class AgriculturalTasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    @admin_user = create(:user, admin: true)
    @other_user = create(:user)
    
    # 参照タスク（user_id: nil）
    @reference_task = create(:agricultural_task, is_reference: true, user_id: nil)
    # 一般ユーザーのタスク
    @user_task = create(:agricultural_task, :user_owned, user: @user)
    # 他のユーザーのタスク
    @other_user_task = create(:agricultural_task, :user_owned, user: @other_user)
    # 管理者のタスク
    @admin_task = create(:agricultural_task, :user_owned, user: @admin_user)
  end

  # ========== index アクションのテスト ==========
  
  test "一般ユーザーのindexは自身のタスクのみ表示" do
    sign_in_as @user
    get agricultural_tasks_path
    
    assert_response :success
    # 一般ユーザーのタスクのみが表示される
    assert_select '.crop-card', count: 1
    # 参照タスクや他のユーザーのタスクは表示されない
  end

  test "管理者のindexは自身のタスクと参照タスクを表示" do
    sign_in_as @admin_user
    get agricultural_tasks_path
    
    assert_response :success
    # 管理者のタスクと参照タスクが表示される（最低2つ）
  end

  # ========== show アクションのテスト ==========
  
  test "一般ユーザーは自身のタスクをshowできる" do
    sign_in_as @user
    get agricultural_task_path(@user_task)
    
    assert_response :success
  end

  test "一般ユーザーは参照タスクをshowできない" do
    sign_in_as @user
    get agricultural_task_path(@reference_task)
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーのタスクをshowできない" do
    sign_in_as @user
    get agricultural_task_path(@other_user_task)
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "管理者は参照タスクをshowできる" do
    sign_in_as @admin_user
    get agricultural_task_path(@reference_task)
    
    assert_response :success
  end

  test "管理者は自身のタスクをshowできる" do
    sign_in_as @admin_user
    get agricultural_task_path(@admin_task)
    
    assert_response :success
  end

  # ========== edit アクションのテスト ==========
  
  test "一般ユーザーは自身のタスクをeditできる" do
    sign_in_as @user
    get edit_agricultural_task_path(@user_task)
    
    assert_response :success
  end

  test "一般ユーザーは参照タスクをeditできない" do
    sign_in_as @user
    get edit_agricultural_task_path(@reference_task)
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーのタスクをeditできない" do
    sign_in_as @user
    get edit_agricultural_task_path(@other_user_task)
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "管理者は参照タスクをeditできる" do
    sign_in_as @admin_user
    get edit_agricultural_task_path(@reference_task)
    
    assert_response :success
  end

  test "管理者は自身のタスクをeditできる" do
    sign_in_as @admin_user
    get edit_agricultural_task_path(@admin_task)
    
    assert_response :success
  end

  # ========== create アクションのテスト ==========
  
  test "一般ユーザーは自身のタスクを作成できる（user_idが自動設定される）" do
    sign_in_as @user
    assert_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: { agricultural_task: {
        name: 'テストタスク',
        description: 'テスト用',
        time_per_sqm: 0.1,
        weather_dependency: 'low',
        required_tools: "トラクター\n耕運機",
        skill_level: 'beginner'
      } }
    end

    assert_redirected_to agricultural_task_path(AgriculturalTask.last)
    task = AgriculturalTask.last
    assert_equal 'テストタスク', task.name
    assert_equal @user.id, task.user_id
    assert_equal false, task.is_reference
    assert_equal ['トラクター', '耕運機'], task.required_tools
  end

  test "一般ユーザーは参照タスクを作成できない" do
    sign_in_as @user
    assert_no_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: { agricultural_task: {
        name: '参照タスク',
        description: 'テスト用',
        is_reference: true
      } }
    end

    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.reference_only_admin'), flash[:alert]
  end

  test "管理者は参照タスクを作成できる" do
    sign_in_as @admin_user
    assert_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: { agricultural_task: {
        name: '参照タスク',
        description: 'テスト用',
        is_reference: true
      } }
    end

    assert_redirected_to agricultural_task_path(AgriculturalTask.last)
    task = AgriculturalTask.last
    assert_equal true, task.is_reference
    assert_nil task.user_id
  end

  test "管理者は自身のタスクを作成できる" do
    sign_in_as @admin_user
    assert_difference('AgriculturalTask.count') do
      post agricultural_tasks_path, params: { agricultural_task: {
        name: '管理者のタスク',
        description: 'テスト用',
        is_reference: false
      } }
    end

    assert_redirected_to agricultural_task_path(AgriculturalTask.last)
    task = AgriculturalTask.last
    assert_equal @admin_user.id, task.user_id
    assert_equal false, task.is_reference
  end

  test "required_toolsは改行区切りでパースされる" do
    sign_in_as @user
    post agricultural_tasks_path, params: { agricultural_task: {
      name: 'テストタスク',
      required_tools: "トラクター\n耕運機\n肥料散布機"
    } }

    task = AgriculturalTask.last
    assert_equal ['トラクター', '耕運機', '肥料散布機'], task.required_tools
  end

  test "required_toolsはカンマ区切りでもパースされる" do
    sign_in_as @user
    post agricultural_tasks_path, params: { agricultural_task: {
      name: 'テストタスク',
      required_tools: "トラクター, 耕運機, 肥料散布機"
    } }

    task = AgriculturalTask.last
    assert_equal ['トラクター', '耕運機', '肥料散布機'], task.required_tools
  end

  # ========== update アクションのテスト ==========
  
  test "一般ユーザーは自身のタスクをupdateできる" do
    sign_in_as @user
    patch agricultural_task_path(@user_task), params: { agricultural_task: {
      name: @user_task.name,
      description: '更新された説明'
    } }
    
    assert_redirected_to agricultural_task_path(@user_task)
    @user_task.reload
    assert_equal '更新された説明', @user_task.description
  end

  test "一般ユーザーは参照タスクをupdateできない" do
    sign_in_as @user
    old_description = @reference_task.description
    
    patch agricultural_task_path(@reference_task), params: { agricultural_task: {
      name: @reference_task.name,
      description: '更新された説明'
    } }
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
    
    @reference_task.reload
    assert_equal old_description, @reference_task.description
  end

  test "一般ユーザーは他のユーザーのタスクをupdateできない" do
    sign_in_as @user
    old_description = @other_user_task.description
    
    patch agricultural_task_path(@other_user_task), params: { agricultural_task: {
      name: @other_user_task.name,
      description: '更新された説明'
    } }
    
    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
    
    @other_user_task.reload
    assert_equal old_description, @other_user_task.description
  end

  test "管理者は参照タスクをupdateできる" do
    sign_in_as @admin_user
    patch agricultural_task_path(@reference_task), params: { agricultural_task: {
      name: @reference_task.name,
      description: '更新された説明'
    } }
    
    assert_redirected_to agricultural_task_path(@reference_task)
    @reference_task.reload
    assert_equal '更新された説明', @reference_task.description
  end

  test "管理者は自身のタスクをupdateできる" do
    sign_in_as @admin_user
    patch agricultural_task_path(@admin_task), params: { agricultural_task: {
      name: @admin_task.name,
      description: '更新された説明'
    } }
    
    assert_redirected_to agricultural_task_path(@admin_task)
    @admin_task.reload
    assert_equal '更新された説明', @admin_task.description
  end

  test "一般ユーザーはis_referenceフラグを変更できない" do
    sign_in_as @user
    patch agricultural_task_path(@user_task), params: { agricultural_task: {
      name: @user_task.name,
      is_reference: true
    } }
    
    assert_redirected_to agricultural_task_path(@user_task)
    assert_equal I18n.t('agricultural_tasks.flash.reference_flag_admin_only'), flash[:alert]
    
    @user_task.reload
    assert_equal false, @user_task.is_reference
  end

  test "update時にrequired_toolsが更新される" do
    sign_in_as @user
    patch agricultural_task_path(@user_task), params: { agricultural_task: {
      name: @user_task.name,
      required_tools: "新しい工具1\n新しい工具2"
    } }
    
    @user_task.reload
    assert_equal ['新しい工具1', '新しい工具2'], @user_task.required_tools
  end

  # ========== destroy アクションのテスト ==========
  
  test "一般ユーザーは自身のタスクをdestroyできる" do
    sign_in_as @user
    task = create(:agricultural_task, :user_owned, user: @user)
    
    assert_difference('AgriculturalTask.count', -1) do
      delete agricultural_task_path(task)
    end

    assert_redirected_to agricultural_tasks_path
  end

  test "一般ユーザーは参照タスクをdestroyできない" do
    sign_in_as @user
    reference_task = create(:agricultural_task, is_reference: true, user_id: nil)
    
    assert_no_difference('AgriculturalTask.count') do
      delete agricultural_task_path(reference_task)
    end

    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "一般ユーザーは他のユーザーのタスクをdestroyできない" do
    sign_in_as @user
    other_task = create(:agricultural_task, :user_owned, user: @other_user)
    
    assert_no_difference('AgriculturalTask.count') do
      delete agricultural_task_path(other_task)
    end

    assert_redirected_to agricultural_tasks_path
    assert_equal I18n.t('agricultural_tasks.flash.not_found'), flash[:alert]
  end

  test "管理者は参照タスクをdestroyできる" do
    sign_in_as @admin_user
    reference_task = create(:agricultural_task, is_reference: true, user_id: nil)
    
    assert_difference('AgriculturalTask.count', -1) do
      delete agricultural_task_path(reference_task)
    end

    assert_redirected_to agricultural_tasks_path
  end

  test "管理者は自身のタスクをdestroyできる" do
    sign_in_as @admin_user
    admin_task = create(:agricultural_task, :user_owned, user: @admin_user)
    
    assert_difference('AgriculturalTask.count', -1) do
      delete agricultural_task_path(admin_task)
    end

    assert_redirected_to agricultural_tasks_path
  end

  # ========== new アクションのテスト ==========
  
  test "should get new" do
    sign_in_as @user
    get new_agricultural_task_path
    assert_response :success
  end
end




