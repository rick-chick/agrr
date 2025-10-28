# frozen_string_literal: true

require 'test_helper'

class CultivationPlanApiTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: "test_#{SecureRandom.hex(8)}"
    )
    
    @farm = Farm.create!(
      user: @user,
      name: 'Test Farm',
      latitude: 35.6762,
      longitude: 139.6503,
      region: 'jp',
      is_reference: false
    )
    
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      plan_type: 'private',
      status: 'completed',
      plan_year: Date.current.year,
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )
    
    # 2つの圃場を作成
    @field1 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: 'Field 1',
      area: 50.0,
      daily_fixed_cost: 10.0
    )
    
    @field2 = CultivationPlanField.create!(
      cultivation_plan: @cultivation_plan,
      name: 'Field 2',
      area: 50.0,
      daily_fixed_cost: 10.0
    )
  end

  test "圃場削除が正常に動作する" do
    # セッションを作成してログイン
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id
    
    # 圃場削除APIを呼び出し
    delete "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/remove_field/#{@field1.id}"
    
    assert_response :success
    
    response_data = JSON.parse(response.body)
    assert response_data['success']
    assert_equal '圃場を削除しました。', response_data['message']
    assert_equal @field1.id, response_data['field_id']
    assert_equal 50.0, response_data['total_area'] # field2の面積のみ
    
    # データベースの確認
    @cultivation_plan.reload
    assert_equal 1, @cultivation_plan.cultivation_plan_fields.count
    assert_equal 50.0, @cultivation_plan.total_area
    assert_nil CultivationPlanField.find_by(id: @field1.id)
  end

  test "栽培スケジュールがある圃場は削除できない" do
    # セッションを作成してログイン
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id
    
    # 栽培スケジュールを作成
    crop = Crop.create!(
      user: @user,
      name: 'Test Crop',
      variety: 'Test Variety',
      area_per_unit: 1.0,
      revenue_per_area: 100.0,
      groups: ['Test Group'],
      region: 'jp',
      is_reference: false
    )
    
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @cultivation_plan,
      crop: crop,
      name: crop.name,
      variety: crop.variety,
      area_per_unit: crop.area_per_unit,
      revenue_per_area: crop.revenue_per_area
    )
    
    FieldCultivation.create!(
      cultivation_plan: @cultivation_plan,
      cultivation_plan_field: @field1,
      cultivation_plan_crop: plan_crop,
      area: 10.0,
      start_date: Date.current,
      completion_date: Date.current + 30.days,
      cultivation_days: 30,
      estimated_cost: 1000.0,
      status: 'completed'
    )
    
    # 圃場削除APIを呼び出し
    delete "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/remove_field/#{@field1.id}"
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['message'], 'この圃場には栽培スケジュールが含まれています'
    
    # データベースの確認（圃場は削除されていない）
    @cultivation_plan.reload
    assert_equal 2, @cultivation_plan.cultivation_plan_fields.count
    assert_not_nil CultivationPlanField.find_by(id: @field1.id)
  end

  test "最後の圃場は削除できない" do
    # セッションを作成してログイン
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id
    
    # field2を削除してfield1のみにする
    @field2.destroy!
    
    # 最後の圃場を削除しようとする
    delete "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/remove_field/#{@field1.id}"
    
    assert_response :unprocessable_entity
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['message'], '最後の圃場は削除できません'
    
    # データベースの確認（圃場は削除されていない）
    @cultivation_plan.reload
    assert_equal 1, @cultivation_plan.cultivation_plan_fields.count
    assert_not_nil CultivationPlanField.find_by(id: @field1.id)
  end

  test "存在しない圃場の削除はエラーになる" do
    # セッションを作成してログイン
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id
    
    # 存在しない圃場IDで削除を試行
    delete "/api/v1/plans/cultivation_plans/#{@cultivation_plan.id}/remove_field/99999"
    
    assert_response :not_found
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['message'], '圃場が見つかりません'
  end

  test "存在しない計画の圃場削除はエラーになる" do
    # セッションを作成してログイン
    session = Session.create_for_user(@user)
    cookies[:session_id] = session.session_id
    
    # 存在しない計画IDで削除を試行
    delete "/api/v1/plans/cultivation_plans/99999/remove_field/#{@field1.id}"
    
    assert_response :not_found
    
    response_data = JSON.parse(response.body)
    assert_not response_data['success']
    assert_includes response_data['message'], '圃場が見つかりません'
  end
end
