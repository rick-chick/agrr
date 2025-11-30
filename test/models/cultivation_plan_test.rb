# frozen_string_literal: true

require 'test_helper'

class CultivationPlanTest < ActiveSupport::TestCase
  def setup
    @user = create(:user)
    @farm = create(:farm, user: @user)
    @plan_year = Date.current.year
  end

  test 'should create valid cultivation plan' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    assert plan.valid?
  end

  test 'should require farm_id for private plans' do
    plan = build(:cultivation_plan, farm: nil, user: @user, plan_year: @plan_year)
    assert_not plan.valid?
    # belongs_to :farm により自動的にpresenceバリデーションが設定される
    assert_includes plan.errors[:farm], "を入力してください"
  end

  test 'should require user_id for private plans' do
    plan = build(:cultivation_plan, farm: @farm, user: nil, plan_year: @plan_year)
    assert_not plan.valid?
    assert_includes plan.errors[:user_id], "を入力してください"
  end

  test 'should allow plan_year to be null for private plans (annual planning)' do
    # 通年計画ではplan_yearがnullでも有効
    plan = build(:cultivation_plan, 
                 farm: @farm, 
                 user: @user, 
                 plan_year: nil,
                 planning_start_date: Date.new(2025, 1, 1),
                 planning_end_date: Date.new(2026, 12, 31))
    assert plan.valid?, "plan_yearがnullでも有効であるべき: #{plan.errors.full_messages}"
  end

  test 'should validate plan_year is greater than 2020' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: 2020)
    assert_not plan.valid?
    assert_includes plan.errors[:plan_year], 'は2020より大きい値にしてください'
  end

  test 'should validate uniqueness of farm_id scoped to user_id for private plans (annual planning)' do
    # 最初の計画を作成（plan_yearあり）
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 同じ農場、ユーザで2つ目の計画を作成しようとする（plan_yearが異なる）
    duplicate_plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year + 1)
    assert_not duplicate_plan.valid?, "同じfarm_id × user_idで複数の計画を作成できないべき"
    assert_includes duplicate_plan.errors[:farm_id], 'この農場の計画は既に存在します'
  end

  test 'should validate uniqueness of farm_id scoped to user_id for private plans without plan_year' do
    # 最初の通年計画を作成（plan_yearなし）
    create(:cultivation_plan, 
           farm: @farm, 
           user: @user, 
           plan_year: nil,
           planning_start_date: Date.new(2025, 1, 1),
           planning_end_date: Date.new(2026, 12, 31))
    
    # 同じ農場、ユーザで2つ目の通年計画を作成しようとする
    duplicate_plan = build(:cultivation_plan, 
                           farm: @farm, 
                           user: @user, 
                           plan_year: nil,
                           planning_start_date: Date.new(2027, 1, 1),
                           planning_end_date: Date.new(2028, 12, 31))
    assert_not duplicate_plan.valid?, "同じfarm_id × user_idで複数の通年計画を作成できないべき"
    assert_includes duplicate_plan.errors[:farm_id], 'この農場の計画は既に存在します'
  end

  test 'should allow same farm_id with different user for private plans' do
    other_user = create(:user)
    other_farm = create(:farm, user: other_user)
    
    # 最初の計画を作成
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 異なるユーザの農場で計画を作成
    other_plan = build(:cultivation_plan, farm: other_farm, user: other_user, plan_year: @plan_year)
    assert other_plan.valid?
  end

  test 'should not allow same farm_id and user with different plan_year for private plans (annual planning)' do
    # 最初の計画を作成（plan_yearあり）
    create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    
    # 異なる年で計画を作成しようとする（通年計画では同じfarm_id × user_idで複数の計画を作成できない）
    different_year_plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year + 1)
    assert_not different_year_plan.valid?, "同じfarm_id × user_idで複数の計画を作成できないべき"
    assert_includes different_year_plan.errors[:farm_id], 'この農場の計画は既に存在します'
  end

  test 'should not validate uniqueness for public plans' do
    # 最初のpublic計画を作成
    create(:cultivation_plan, :public_plan, farm: @farm)
    
    # 同じ農場で2つ目のpublic計画を作成
    duplicate_public_plan = build(:cultivation_plan, :public_plan, farm: @farm)
    assert duplicate_public_plan.valid?
  end

  test 'should validate total_area presence' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, total_area: nil)
    assert_not plan.valid?
    assert_includes plan.errors[:total_area], "を入力してください"
  end

  test 'should validate total_area is greater than or equal to 0' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, total_area: -1)
    assert_not plan.valid?
    assert_includes plan.errors[:total_area], 'は0以上の値にしてください'
  end

  test 'should validate status inclusion' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan.status = 'invalid_status'
    assert_not plan.valid?
    assert_includes plan.errors[:status], 'は一覧にありません'
  rescue ArgumentError => e
    # enumの値が無効な場合はArgumentErrorが発生する
    assert_match(/is not a valid status/, e.message)
  end

  test 'should validate plan_type inclusion' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan.plan_type = 'invalid_type'
    assert_not plan.valid?
    assert_includes plan.errors[:plan_type], 'は一覧にありません'
  rescue ArgumentError => e
    # enumの値が無効な場合はArgumentErrorが発生する
    assert_match(/is not a valid plan_type/, e.message)
  end

  test 'should validate planning_start_date presence for private plans' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, planning_start_date: nil)
    assert_not plan.valid?
    assert_includes plan.errors[:planning_start_date], "を入力してください"
  end

  test 'should validate planning_end_date presence for private plans' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, planning_end_date: nil)
    assert_not plan.valid?
    assert_includes plan.errors[:planning_end_date], "を入力してください"
  end

  test 'should calculate planning dates from plan year' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    expected_dates = CultivationPlan.calculate_planning_dates(@plan_year)
    
    assert_equal expected_dates[:start_date], plan.planning_start_date
    assert_equal expected_dates[:end_date], plan.planning_end_date
  end

  test 'should return correct display name for private plan with plan_year' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, plan_name: 'テスト計画')
    expected_name = "テスト計画 (#{@plan_year})"
    assert_equal expected_name, plan.display_name
  end

  test 'should return display name with date range for private plan without plan_year' do
    plan = create(:cultivation_plan, 
                  farm: @farm, 
                  user: @user, 
                  plan_year: nil,
                  plan_name: 'テスト計画',
                  planning_start_date: Date.new(2025, 1, 1),
                  planning_end_date: Date.new(2026, 12, 31))
    expected_name = "テスト計画 (2025〜2026)"
    assert_equal expected_name, plan.display_name
  end

  test 'should return default display name for private plan without plan_name' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year, plan_name: nil)
    expected_name = I18n.t('models.cultivation_plan.default_plan_name') + " (#{@plan_year})"
    assert_equal expected_name, plan.display_name
  end

  test 'should return display name without year for private plan without plan_year and dates' do
    plan = build(:cultivation_plan, 
                 farm: @farm, 
                 user: @user, 
                 plan_year: nil,
                 plan_name: 'テスト計画',
                 planning_start_date: nil,
                 planning_end_date: nil)
    # planning_start_dateとplanning_end_dateがnullの場合はplan_nameのみ
    assert_equal 'テスト計画', plan.display_name
  end

  test 'should return public plan name for public plan' do
    plan = create(:cultivation_plan, :public_plan, farm: @farm)
    expected_name = I18n.t('models.cultivation_plan.public_plan_name')
    assert_equal expected_name, plan.display_name
  end

  test 'should require weather prediction' do
    plan = build(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    assert plan.requires_weather_prediction?
  end

  test 'destroying plan removes dependent schedules and items without foreign key errors' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop
    )
    task_schedule = create(:task_schedule, cultivation_plan: plan, field_cultivation: field_cultivation)
    create(:task_schedule_item, task_schedule: task_schedule)

    assert_difference('CultivationPlan.count', -1) do
      assert_nothing_raised { plan.destroy }
    end

    assert_not TaskSchedule.exists?(task_schedule.id)
    assert_not FieldCultivation.exists?(field_cultivation.id)
  end

  # 計算メソッドのテスト
  test 'calculated_planning_start_date with field_cultivations' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # plan_yearが設定されている場合は保存されているカラムを優先
    expected_start_date = plan.planning_start_date
    assert_equal expected_start_date, plan.calculated_planning_start_date
  end

  test 'calculated_planning_start_date without field_cultivations for private plan' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan.field_cultivations.destroy_all
    
    assert_equal Date.current.beginning_of_year, plan.calculated_planning_start_date
  end

  test 'calculated_planning_start_date without field_cultivations for public plan' do
    plan = create(:cultivation_plan, :public_plan, farm: @farm)
    plan.field_cultivations.destroy_all
    
    assert_equal Date.current, plan.calculated_planning_start_date
  end

  test 'calculated_planning_end_date with field_cultivations' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # plan_yearが設定されている場合は保存されているカラムを優先
    expected_end_date = plan.planning_end_date
    assert_equal expected_end_date, plan.calculated_planning_end_date
  end

  test 'calculated_planning_end_date without field_cultivations for private plan' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan.field_cultivations.destroy_all
    
    assert_equal Date.new(Date.current.year + 1, 12, 31), plan.calculated_planning_end_date
  end

  test 'calculated_planning_end_date without field_cultivations for public plan' do
    plan = create(:cultivation_plan, :public_plan, farm: @farm)
    plan.field_cultivations.destroy_all
    
    assert_equal Date.current.end_of_year, plan.calculated_planning_end_date
  end

  test 'calculated_planning_start_date prioritizes stored column when plan_year is set' do
    plan_year = 2025
    plan = create(:cultivation_plan, 
                  farm: @farm, 
                  user: @user, 
                  plan_year: plan_year,
                  planning_start_date: Date.new(plan_year, 1, 1),
                  planning_end_date: Date.new(plan_year + 1, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    # field_cultivationsが2025年のみに存在しても、plan_yearが設定されている場合は保存されているカラムを優先
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(plan_year, 4, 1),
      completion_date: Date.new(plan_year, 10, 31)
    )
    
    # plan_yearが設定されている場合は保存されているカラムを優先（2025年1月1日）
    assert_equal Date.new(plan_year, 1, 1), plan.calculated_planning_start_date
    # field_cultivationsから計算すると2025年1月1日になるが、カラムの値が優先される
  end

  test 'calculated_planning_end_date prioritizes stored column when plan_year is set' do
    plan_year = 2025
    plan = create(:cultivation_plan, 
                  farm: @farm, 
                  user: @user, 
                  plan_year: plan_year,
                  planning_start_date: Date.new(plan_year, 1, 1),
                  planning_end_date: Date.new(plan_year + 1, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    # field_cultivationsが2025年のみに存在しても、plan_yearが設定されている場合は保存されているカラムを優先
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(plan_year, 4, 1),
      completion_date: Date.new(plan_year, 10, 31)
    )
    
    # plan_yearが設定されている場合は保存されているカラムを優先（2026年12月31日）
    assert_equal Date.new(plan_year + 1, 12, 31), plan.calculated_planning_end_date
    # field_cultivationsから計算すると2025年12月31日になるが、カラムの値が優先される
  end

  test 'calculated_planning_start_date uses field_cultivations when plan_year is not set' do
    plan = create(:cultivation_plan, 
                  farm: @farm, 
                  user: @user, 
                  plan_year: nil,
                  planning_start_date: Date.new(2025, 1, 1),
                  planning_end_date: Date.new(2026, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # plan_yearが設定されていない場合はfield_cultivationsから計算（2025年1月1日）
    assert_equal Date.new(2025, 1, 1), plan.calculated_planning_start_date
  end

  test 'calculated_planning_end_date uses field_cultivations when plan_year is not set' do
    plan = create(:cultivation_plan, 
                  farm: @farm, 
                  user: @user, 
                  plan_year: nil,
                  planning_start_date: Date.new(2025, 1, 1),
                  planning_end_date: Date.new(2026, 12, 31))
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # plan_yearが設定されていない場合はfield_cultivationsから計算（2025年12月31日）
    assert_equal Date.new(2025, 12, 31), plan.calculated_planning_end_date
  end

  test 'calculated_planning_start_date with nil dates' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: nil,
      completion_date: nil
    )
    
    # nilの場合はデフォルト値を返す
    assert_equal Date.current.beginning_of_year, plan.calculated_planning_start_date
  end

  test 'calculated_planning_range returns hash with start and end dates' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    range = plan.calculated_planning_range
    # plan_yearが設定されている場合は保存されているカラムを優先
    assert_equal plan.planning_start_date, range[:start_date]
    assert_equal plan.planning_end_date, range[:end_date]
  end

  test 'planning_start_date returns nil when column is nil (for validation)' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # カラムの値をnilに設定
    plan.update_column(:planning_start_date, nil)
    plan.reload
    
    # カラムがnilの場合はnilを返す（バリデーションのため）
    assert_nil plan.planning_start_date
    
    # 計算メソッドは別途使用可能
    assert_equal Date.new(2025, 1, 1), plan.calculated_planning_start_date
  end

  test 'planning_end_date returns nil when column is nil (for validation)' do
    plan = create(:cultivation_plan, farm: @farm, user: @user, plan_year: @plan_year)
    plan_field = create(:cultivation_plan_field, cultivation_plan: plan)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: plan)
    field_cultivation = create(
      :field_cultivation,
      cultivation_plan: plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 4, 1),
      completion_date: Date.new(2025, 10, 31)
    )
    
    # カラムの値をnilに設定
    plan.update_column(:planning_end_date, nil)
    plan.reload
    
    # カラムがnilの場合はnilを返す（バリデーションのため）
    assert_nil plan.planning_end_date
    
    # 計算メソッドは別途使用可能
    assert_equal Date.new(2025, 12, 31), plan.calculated_planning_end_date
  end
end
