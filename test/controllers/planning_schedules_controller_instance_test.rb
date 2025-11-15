# frozen_string_literal: true

require 'test_helper'

class PlanningSchedulesControllerInstanceTest < ActionController::TestCase
  tests PlanningSchedulesController

  setup do
    @user = create(:user)
    @farm = create(:farm, user: @user, name: 'テスト農場')
    @session = create(:session, user: @user)
    @request.cookies[:session_id] = @session.session_id
  end

  test "fields_selection sets year_range in descending order" do
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: Date.current.year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get :fields_selection, params: { farm_id: @farm.id }
    
    assert_response :success
    
    # コントローラーのインスタンス変数を直接確認
    year_range = @controller.instance_variable_get(:@year_range)
    
    assert_not_nil year_range, "@year_range should be set"
    assert_equal 5, year_range.size, "Should have 5 years"
    
    # 降順であることを確認（各要素が前の要素より大きい）
    year_range.each_cons(2) do |current, next_year|
      assert current > next_year, "Year range should be in descending order: #{current} should be greater than #{next_year}, but got #{year_range.inspect}"
    end
    
    # 来年から過去5年分であることを確認
    current_year = Date.current.year
    next_year = current_year + 1
    expected_first = next_year
    expected_last = next_year - 4
    
    assert_equal expected_first, year_range.first, "First year should be next year (#{expected_first}), but got #{year_range.first}"
    assert_equal expected_last, year_range.last, "Last year should be 5 years before next year (#{expected_last}), but got #{year_range.last}"
  end

  test "schedule sets year_range in descending order" do
    current_year = Date.current.year
    field_id = 'ほ場1'.hash.abs
    
    plan = create(:cultivation_plan, :private, user: @user, farm: @farm, plan_year: current_year)
    field1 = create(:cultivation_plan_field, cultivation_plan: plan, name: 'ほ場1', area: 1000)
    
    get :schedule, params: {
      farm_id: @farm.id,
      field_ids: [field_id],
      year: current_year,
      granularity: 'quarter'
    }
    
    assert_response :success
    
    # コントローラーのインスタンス変数を直接確認
    year_range = @controller.instance_variable_get(:@year_range)
    
    assert_not_nil year_range, "@year_range should be set"
    assert_equal 5, year_range.size, "Should have 5 years"
    
    # 降順であることを確認（各要素が前の要素より大きい）
    year_range.each_cons(2) do |current, next_year|
      assert current > next_year, "Year range should be in descending order: #{current} should be greater than #{next_year}, but got #{year_range.inspect}"
    end
    
    # 来年から過去5年分であることを確認
    next_year = current_year + 1
    expected_first = next_year
    expected_last = next_year - 4
    
    assert_equal expected_first, year_range.first, "First year should be next year (#{expected_first}), but got #{year_range.first}"
    assert_equal expected_last, year_range.last, "Last year should be 5 years before next year (#{expected_last}), but got #{year_range.last}"
    
    # @periodsが降順になっていることを確認
    periods = @controller.instance_variable_get(:@periods)
    assert_not_nil periods, "@periods should be set"
    assert periods.size > 0, "@periods should have at least one period"
    
    # 降順であることを確認（各期間の開始日が前の期間より大きい）
    periods.each_cons(2) do |current_period, next_period|
      assert current_period[:start_date] > next_period[:start_date], 
        "Periods should be in descending order: #{current_period[:label]} (#{current_period[:start_date]}) should be after #{next_period[:label]} (#{next_period[:start_date]})"
    end
  end
end

