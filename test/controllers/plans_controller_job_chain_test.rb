# frozen_string_literal: true

require 'test_helper'

class PlansControllerJobChainTest < ActionController::TestCase
  tests PlansController

  setup do
    @user = create(:user)
    sign_in_as @user

    @weather_location = WeatherLocation.create!(
      latitude: 36.0,
      longitude: 140.0,
      elevation: 50.0,
      timezone: 'Asia/Tokyo'
    )

    @farm = create(:farm, user: @user, latitude: 36.0, longitude: 140.0, region: 'jp', weather_location: @weather_location)
    @plan = create(:cultivation_plan, farm: @farm, user: @user, plan_type: 'private')
  end

  def build_crop_for_plan(with_blueprint:)
    crop = create(:crop, user: @user, is_reference: false, region: 'jp', revenue_per_area: 1000.0)
    create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    if with_blueprint
      # 作業テンプレート（blueprint）を1つ紐づける
      create(:crop_task_schedule_blueprint, crop: crop)
    end
    crop
  end

  test 'job chain includes schedule generation and finalize when all crops have blueprints' do
    # 作物を2つ用意し、両方にblueprintを付与
    build_crop_for_plan(with_blueprint: true)
    build_crop_for_plan(with_blueprint: true)

    controller = PlansController.new
    job_instances = controller.send(:create_job_instances_for_plans, @plan.id, PlansOptimizationChannel)

    # 先頭3つは 天気→予測→最適化
    assert_instance_of FetchWeatherDataJob, job_instances[0]
    assert_instance_of WeatherPredictionJob, job_instances[1]
    assert_instance_of OptimizationJob, job_instances[2]
    # 4つ目がスケジュール生成、5つ目がファイナライズ
    assert_instance_of TaskScheduleGenerationJob, job_instances[3]
    assert_instance_of PlanFinalizeJob, job_instances[4]
  end

  test 'job chain skips schedule generation and includes finalize when some crop misses blueprints' do
    # 片方のみ blueprint を用意（もう片方は無し）
    build_crop_for_plan(with_blueprint: true)
    build_crop_for_plan(with_blueprint: false)

    controller = PlansController.new
    job_instances = controller.send(:create_job_instances_for_plans, @plan.id, PlansOptimizationChannel)

    # 先頭3つは 天気→予測→最適化
    assert_instance_of FetchWeatherDataJob, job_instances[0]
    assert_instance_of WeatherPredictionJob, job_instances[1]
    assert_instance_of OptimizationJob, job_instances[2]
    # 4つ目はファイナライズ（スケジュール生成は入らない）
    assert_equal 4, job_instances.length
    assert_instance_of PlanFinalizeJob, job_instances[3]
  end
end


