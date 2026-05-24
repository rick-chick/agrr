# frozen_string_literal: true

require "test_helper"

class PrivatePlanOptimizationJobChainBuilderTest < ActiveSupport::TestCase
  setup do
    @user = create(:user)
    @weather_location = WeatherLocation.find_or_create_by!(latitude: 36.0, longitude: 140.0) do |wl|
      wl.elevation = 50.0
      wl.timezone = "Asia/Tokyo"
    end
    @farm = create(:farm, user: @user, latitude: 36.0, longitude: 140.0, region: "jp", weather_location: @weather_location)
    @plan = create(:cultivation_plan, farm: @farm, user: @user, plan_type: "private")
  end

  def build_crop_for_plan(with_blueprint:)
    crop = create(:crop, user: @user, is_reference: false, region: "jp", revenue_per_area: 1000.0)
    create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    create(:crop_task_schedule_blueprint, crop: crop) if with_blueprint
    crop
  end

  test "job chain includes schedule generation and finalize when all crops have blueprints" do
    build_crop_for_plan(with_blueprint: true)
    build_crop_for_plan(with_blueprint: true)

    builder = Adapters::CultivationPlan::PrivatePlanOptimizationJobChainBuilder.new(
      logger: Rails.logger,
      clock: Time.zone
    )
    job_instances = builder.build(cultivation_plan_id: @plan.id, channel_class: PlansOptimizationChannel)

    assert_instance_of FetchWeatherDataJob, job_instances[0]
    assert_instance_of WeatherPredictionJob, job_instances[1]
    assert_instance_of OptimizationJob, job_instances[2]
    assert_instance_of TaskScheduleGenerationJob, job_instances[3]
    assert_instance_of PlanFinalizeJob, job_instances[4]
  end

  test "job chain skips schedule generation and includes finalize when some crop misses blueprints" do
    build_crop_for_plan(with_blueprint: true)
    build_crop_for_plan(with_blueprint: false)

    builder = Adapters::CultivationPlan::PrivatePlanOptimizationJobChainBuilder.new(
      logger: Rails.logger,
      clock: Time.zone
    )
    job_instances = builder.build(cultivation_plan_id: @plan.id, channel_class: PlansOptimizationChannel)

    assert_instance_of FetchWeatherDataJob, job_instances[0]
    assert_instance_of WeatherPredictionJob, job_instances[1]
    assert_instance_of OptimizationJob, job_instances[2]
    assert_equal 4, job_instances.length
    assert_instance_of PlanFinalizeJob, job_instances[3]
  end
end
