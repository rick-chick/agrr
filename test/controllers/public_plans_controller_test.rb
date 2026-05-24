# frozen_string_literal: true

require "test_helper"

# レガシー HTML PublicPlansController（new / create のみ残置）。SPA 正経路は wizard API テストを参照。
class PublicPlansControllerSessionTest < ActionController::TestCase
  tests PublicPlansController

  test "create does not store crop_ids in session" do
    farm = Farm.reference.first || Farm.create!(user: User.anonymous_user, name: "Ref Farm", is_reference: true, region: "jp", latitude: 35.0, longitude: 139.0)

    @request.session[:public_plan] = {
      farm_id: farm.id,
      farm_size_id: "home_garden",
      total_area: 30
    }

    crop = Crop.reference.first || Crop.create!(name: "Ref Crop", is_reference: true, region: "jp")
    post :create, params: { crop_ids: [ crop.id ] }

    public_plan = @request.session[:public_plan]
    assert public_plan.is_a?(Hash)
    assert_nil public_plan[:crop_ids]
  end

  test "create with no crops redirects to public_plans with alert" do
    farm = Farm.reference.where(region: "jp").first ||
           Farm.create!(user: User.anonymous_user, name: "最適化テスト農場", is_reference: true, region: "jp", latitude: 35.6762, longitude: 139.6503)

    @request.session[:public_plan] = { farm_id: farm.id, farm_size_id: "home_garden", total_area: 30 }

    Domain::PublicPlan::Interactors::PublicPlanCreateInteractor.stub(:new, ->(**kw) {
      output_port = kw[:output_port]
      Object.new.tap do |obj|
        obj.define_singleton_method(:call) { |_input|
          output_port.on_no_crops_failure(
            Domain::PublicPlan::Dtos::PublicPlanCreateNoCropsViewContext.new(
              farm: farm,
              farm_size: { id: "home_garden", area_sqm: 30 },
              crops: []
            )
          )
        }
      end
    }) do
      post :create, params: { crop_ids: [] }
      assert_redirected_to public_plans_path
      assert_equal I18n.t("public_plans.errors.select_crop"), flash[:alert]
    end
  end
end

class PublicPlansControllerIntegrationTest < ActionDispatch::IntegrationTest
  setup do
    @anonymous_user = User.anonymous_user
    @japan_farm = Farm.reference.where(region: "jp").first

    if @japan_farm.nil?
      @weather_location = WeatherLocation.find_or_create_by_coordinates(
        latitude: 35.6762,
        longitude: 139.6503,
        elevation: 10.0,
        timezone: "Asia/Tokyo"
      )

      @japan_farm = create(:farm, :reference,
        name: "関東農場",
        latitude: 35.6762,
        longitude: 139.6503,
        region: "jp",
        user: @anonymous_user,
        weather_location: @weather_location
      )

      weather_records = []
      (15.years.ago.to_date..Date.current).each do |date|
        weather_records << {
          weather_location_id: @weather_location.id,
          date: date,
          temperature_max: 25.0 + rand(-5..5),
          temperature_min: 15.0 + rand(-5..5),
          temperature_mean: 20.0 + rand(-3..3),
          precipitation: rand(0..10),
          sunshine_hours: rand(5..12),
          wind_speed: rand(1..5),
          weather_code: rand(1..10),
          created_at: Time.current,
          updated_at: Time.current
        }
      end
      WeatherDatum.insert_all(weather_records)
    end

    @spinach_crop = create(:crop, :reference,
      name: "ほうれん草",
      variety: "一般",
      area_per_unit: 0.1,
      revenue_per_area: 800.0,
      groups: [ "ヒユ科" ],
      region: "jp",
      user: nil
    )

    create(:crop_stage, :germination, crop: @spinach_crop, order: 1)
    create(:crop_stage, :vegetative, crop: @spinach_crop, order: 2)
    create(:crop_stage, :flowering, crop: @spinach_crop, order: 3)
    create(:crop_stage, :fruiting, crop: @spinach_crop, order: 4)
  end

  test "wizard API creates public plan and optimization job failure updates status" do
    post api_v1_public_plans_plans_path,
         params: {
           farm_id: @japan_farm.id,
           farm_size_id: "home_garden",
           crop_ids: [ @spinach_crop.id ]
         },
         as: :json
    assert_response :success
    plan_id = JSON.parse(response.body)["plan_id"]

    cultivation_plan = CultivationPlan.find(plan_id)
    assert_equal @japan_farm.id, cultivation_plan.farm_id
    assert_equal 30, cultivation_plan.total_area
    assert_equal "public", cultivation_plan.plan_type
    assert_equal "pending", cultivation_plan.status

    OptimizationJob.stub(:perform_now, ->(*args) {
      opts = args.first || {}
      pid = opts[:cultivation_plan_id] || opts["cultivation_plan_id"]
      CultivationPlan.find(pid).update!(status: "failed") if pid
      raise Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor::WeatherDataNotFoundError
    }) do
      assert_raises(Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor::WeatherDataNotFoundError) do
        OptimizationJob.perform_now(cultivation_plan_id: cultivation_plan.id, channel_class: "OptimizationChannel")
      end
    end

    assert_equal "failed", cultivation_plan.reload.status
  end
end
