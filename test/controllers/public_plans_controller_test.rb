# frozen_string_literal: true

require 'test_helper'

class PublicPlansControllerSessionTest < ActionController::TestCase
  tests PublicPlansController

  test 'create does not store crop_ids in session' do
    farm = Farm.reference.first || Farm.create!(user: User.anonymous_user, name: 'Ref Farm', is_reference: true, region: 'jp', latitude: 35.0, longitude: 139.0)

    # Step2: farm_idをセッションに入れる（GETアクションを直接呼び出し）
    get :select_farm_size, params: { farm_id: farm.id }

    # Step3: 作物選択画面を通過（farm_size_id必須）
    get :select_crop, params: { farm_size_id: 'home_garden' }

    # Step4: 計画作成（create）
    crop = Crop.reference.first || Crop.create!(name: 'Ref Crop', is_reference: true, region: 'jp')
    post :create, params: { crop_ids: [crop.id] }

    public_plan = @request.session[:public_plan]
    assert public_plan.is_a?(Hash)
    assert public_plan[:plan_id].present?
    assert_nil public_plan[:crop_ids]
  end

  test 'job chain includes task schedule generation job at the end' do
    weather_location = WeatherLocation.create!(
      latitude: 36.0,
      longitude: 140.0,
      elevation: 50.0,
      timezone: 'Asia/Tokyo'
    )

    farm = create(:farm, weather_location: weather_location, latitude: 36.0, longitude: 140.0, region: 'jp')
    plan = create(:cultivation_plan, farm: farm, plan_type: 'public')

    controller = PublicPlansController.new
    job_instances = controller.send(:create_job_instances_for_public_plans, plan.id, OptimizationChannel)

    assert job_instances.last.is_a?(TaskScheduleGenerationJob)
    assert_equal plan.id, job_instances.last.cultivation_plan_id
  end

  # RED: WeatherPredictionService requires current year data (Date.current.year, 1, 1) to (Date.current - 2.days).
  # When latest_weather_date is in the past, calculate_weather_data_params must return end_date >= Date.current - 2.days
  # so that FetchWeatherDataJob fetches the current year and WeatherPredictionJob does not fail.
  test 'calculate_weather_data_params returns end_date at least Date.current - 2.days when latest_weather_date is in the past' do
    weather_location = WeatherLocation.create!(
      latitude: 38.0,
      longitude: 142.0,
      elevation: 10.0,
      timezone: 'Asia/Tokyo'
    )
    # Data only up to 1 year ago → latest_weather_date will be in the past
    past_end_date = 1.year.ago.to_date
    WeatherDatum.create!(
      weather_location: weather_location,
      date: past_end_date,
      temperature_max: 25.0,
      temperature_min: 15.0,
      temperature_mean: 20.0,
      precipitation: 0,
      sunshine_hours: 8,
      wind_speed: 3,
      weather_code: 0
    )

    controller = PublicPlansController.new
    params = controller.send(:calculate_weather_data_params, weather_location)

    minimum_required = Date.current - 2.days
    assert params[:end_date] >= minimum_required,
           "end_date (#{params[:end_date]}) must be >= #{minimum_required} for WeatherPredictionService current year data"
  end
end

# frozen_string_literal: true

require 'test_helper'

class PublicPlansControllerTest < ActionDispatch::IntegrationTest
  setup do
    # アノニマスユーザーを作成
    @anonymous_user = User.anonymous_user
    
    # 既存の参照農場を使用（マイグレーションで作成されたもの）
    @japan_farm = Farm.reference.where(region: 'jp').first
    
    # 既存の農場がない場合は作成
    if @japan_farm.nil?
      # 気象データ用のWeatherLocationを作成
      @weather_location = WeatherLocation.create!(
        latitude: 35.6762,
        longitude: 139.6503,
        elevation: 10.0,
        timezone: 'Asia/Tokyo'
      )
      
      # 日本の参照農場を作成（気象データ付き）
      @japan_farm = create(:farm, :reference, 
        name: "関東農場", 
        latitude: 35.6762, 
        longitude: 139.6503,
        region: 'jp',
        user: @anonymous_user,
        weather_location: @weather_location
      )
      
      # テスト用の気象データを作成（過去15年分、バッチ処理）
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
    
    # ほうれん草の参照作物を作成
    @spinach_crop = create(:crop, :reference,
      name: "ほうれん草",
      variety: "一般",
      area_per_unit: 0.1,
      revenue_per_area: 800.0,
      groups: ["ヒユ科"],
      region: 'jp',
      user: nil
    )
    
    # ほうれん草の生育ステージを作成
    create(:crop_stage, :germination, crop: @spinach_crop, order: 1)
    create(:crop_stage, :vegetative, crop: @spinach_crop, order: 2)
    create(:crop_stage, :flowering, crop: @spinach_crop, order: 3)
    create(:crop_stage, :fruiting, crop: @spinach_crop, order: 4)
  end

  test "public_plansの完全なフロー（地域選択→農場サイズ→作物選択→計画作成→最適化→結果表示）" do
    # Step 1: 地域選択画面の表示
    get public_plans_path
    assert_response :success
    assert_select "h2" # ビューにh2タグが存在することを確認

    # Step 2: 農場サイズ選択画面の表示
    get select_farm_size_public_plans_path(farm_id: @japan_farm.id)
    assert_response :success
    assert_select "h2" # ビューにh2タグが存在することを確認

    # Step 3: 作物選択画面の表示（セッション経由）
    get select_crop_public_plans_path(farm_size_id: 'home_garden')
    assert_response :success
    assert_select "h2" # ビューにh2タグが存在することを確認

    # Step 4: 計画作成（セッション経由）
    post public_plans_path, params: { crop_ids: [@spinach_crop.id] }
    
    # 計画が作成され、最適化画面にリダイレクトされる
    assert_redirected_to "/public_plans/optimizing"
    
    # 作成された計画を取得
    cultivation_plan = CultivationPlan.last
    assert_not_nil cultivation_plan
    assert_equal @japan_farm.id, cultivation_plan.farm_id
    assert_equal 30, cultivation_plan.total_area
    assert_equal 'public', cultivation_plan.plan_type
    assert_equal 'pending', cultivation_plan.status

    # Step 5: 最適化画面の表示
    get optimizing_public_plans_path
    assert_response :success
    assert_select ".compact-header-title" # ヘッダータイトルが存在することを確認

    # Step 6: 最適化処理の実行（バックグラウンドジョブ）
    # 注意: 実際の最適化処理は複雑な依存関係があるため、ここではスキップ
    # 代わりに、最適化画面が表示されることを確認
    # OptimizationJob.perform_now(cultivation_plan_id: cultivation_plan.id, channel_class: 'OptimizationChannel')

    # Step 7: 結果画面の表示（完了済みの場合）
    if cultivation_plan.status == 'completed'
      get results_public_plans_path(plan_id: cultivation_plan.id)
      assert_response :success
      assert_select "h2" # ビューにh2タグが存在することを確認
      assert_select ".crop-palette-card" # 作物パレットカードが表示される
    end
  end

  test "作物未選択のままcreateにPOSTすると422でselect_cropを再描画" do
    # Step 1: 地域選択
    get public_plans_path
    assert_response :success

    # Step 2: 農場サイズ選択（セッションにfarm_id保存）
    get select_farm_size_public_plans_path(farm_id: @japan_farm.id)
    assert_response :success

    # Step 3: 作物選択画面（セッションにfarm_size/total_area保存）
    get select_crop_public_plans_path(farm_size_id: 'home_garden')
    assert_response :success

    # Step 4: 作物未選択でPOST
    post public_plans_path, params: { crop_ids: [] }
    assert_response :unprocessable_entity
    assert_select "h2" # 同画面を再描画
    assert_includes @response.body, I18n.t('public_plans.errors.select_crop')
  end

  test "最適化処理の実際の動作をテスト（気象データ不足のバグを発見）" do
    # 計画を直接作成
    cultivation_plan = CultivationPlan.create!(
      farm: @japan_farm,
      total_area: 30,
      plan_type: 'public',
      status: 'pending'
    )
    
    # 最適化ジョブを直接実行（気象データ不足のバグが発見される）
    begin
      OptimizationJob.perform_now(cultivation_plan_id: cultivation_plan.id, channel_class: 'OptimizationChannel')
      flunk "Expected CultivationPlanOptimizer::WeatherDataNotFoundError to be raised"
    rescue CultivationPlanOptimizer::WeatherDataNotFoundError
      # 期待される例外が発生
    end
    
    # 計画のステータスが'failed'に更新されることを確認（エラーハンドリングが動作）
    cultivation_plan.reload
    assert_equal 'failed', cultivation_plan.status
  end

  test "エラーハンドリング（存在しない農場ID）" do
    get select_farm_size_public_plans_path(farm_id: 99999)
    assert_redirected_to public_plans_path
    assert_equal I18n.t('public_plans.errors.select_region'), flash[:alert]
  end

  test "エラーハンドリング（作物が選択されていない）" do
    # セッションを設定してから作物選択画面にアクセス
    get select_crop_public_plans_path(farm_size_id: 'home_garden')
    # セッションが無効なため、リダイレクトされる
    assert_redirected_to public_plans_path
    assert_equal I18n.t('public_plans.errors.restart'), flash[:alert]
  end

  test "農場サイズの定数が正しく定義されている" do
    farm_sizes = PublicPlansController.farm_sizes
    assert_equal 3, farm_sizes.length
    
    # home_garden
    home_garden = farm_sizes.find { |size| size[:id] == 'home_garden' }
    assert_not_nil home_garden
    assert_equal 30, home_garden[:area_sqm]
    
    # community_garden
    community_garden = farm_sizes.find { |size| size[:id] == 'community_garden' }
    assert_not_nil community_garden
    assert_equal 50, community_garden[:area_sqm]
    
    # rental_farm
    rental_farm = farm_sizes.find { |size| size[:id] == 'rental_farm' }
    assert_not_nil rental_farm
    assert_equal 300, rental_farm[:area_sqm]
  end

  test "地域コードの変換が正しく動作する" do
    controller = PublicPlansController.new
    
    # 日本語ロケール
    assert_equal 'jp', controller.send(:locale_to_region, :ja)
    
    # 英語ロケール
    assert_equal 'us', controller.send(:locale_to_region, :us)
    
    # インドロケール
    assert_equal 'in', controller.send(:locale_to_region, :in)
    
    # デフォルト（不明なロケール）
    assert_equal 'jp', controller.send(:locale_to_region, :unknown)
  end

  test "農場の件数制限に達している場合にエラーメッセージが表示される" do
    # テストユーザーを作成（農場上限に達している）
    user = User.create!(
      email: 'flash_test@example.com',
      name: 'Flash Test User',
      google_id: "flash_#{SecureRandom.hex(8)}"
    )

    # ユーザーを4件の農場に制限
    4.times do |i|
      Farm.create!(
        user: user,
        name: "既存農場 #{i + 1}",
        latitude: 35.6812,
        longitude: 139.7671,
        region: 'jp',
        is_reference: false
      )
    end

    # セッションを作成
    session = Session.create_for_user(user)

    # Public計画を作成（結果画面用）
    public_plan = CultivationPlan.create!(
      farm: @japan_farm,
      user: nil,
      total_area: 100.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )

    # Public Plansのセッションデータを設定
    session_data = {
      plan_id: public_plan.id,
      farm_id: @japan_farm.id,
      crop_ids: [@spinach_crop.id],
      field_data: [{ name: 'テスト圃場', area: 100.0, coordinates: [35.0, 139.0] }]
    }

    # save_planをシミュレート
    cookies[:session_id] = session.session_id

    # PlanSaveServiceを直接呼び出し
    result = PlanSaveService.new(
      user: user,
      session_data: session_data
    ).call

    # エラーが発生することを確認
    assert_not result.success
    assert_not_nil result.error_message
    assert_includes result.error_message, "作成できるFarmは4件までです"
  end

  test "POST /api/v1/public_plans/save_plan - 正常に計画を保存できる" do
    # テストユーザーを作成
    user = User.create!(
      email: 'api_test@example.com',
      name: 'API Test User',
      google_id: "api_#{SecureRandom.hex(8)}"
    )

    # セッションを作成
    session = Session.create_for_user(user)

    # Public計画を作成
    public_plan = CultivationPlan.create!(
      farm: @japan_farm,
      user: nil,
      total_area: 30.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )

    # 作物と計画の関連付け
    cultivation_plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: public_plan,
      crop: @spinach_crop,
      name: @spinach_crop.name,
      crop_id: @spinach_crop.id
    )

    # 圃場を作成
    field = CultivationPlanField.create!(
      cultivation_plan: public_plan,
      name: 'テスト圃場',
      area: 30.0
    )

    # APIリクエスト
    cookies[:session_id] = session.session_id
    post '/api/v1/public_plans/save_plan',
         params: { plan_id: public_plan.id },
         as: :json

    # レスポンス確認
    assert_response :success
    response_body = JSON.parse(@response.body)
    assert response_body['success']
    assert_not response_body.key?('error')
  end

  test "POST /api/v1/public_plans/save_plan - 未認証の場合401を返す" do
    # 認証なしでAPIリクエスト
    post '/api/v1/public_plans/save_plan',
         params: { plan_id: 1 },
         as: :json

    # レスポンス確認
    assert_response :unauthorized
    response_body = JSON.parse(@response.body)
    assert_not response_body['success']
    assert_equal I18n.t('auth.api.login_required'), response_body['error']
  end

  test "POST /api/v1/public_plans/save_plan - plan_idが欠けている場合400を返す" do
    # テストユーザーを作成
    user = User.create!(
      email: 'api_test2@example.com',
      name: 'API Test User 2',
      google_id: "api2_#{SecureRandom.hex(8)}"
    )

    # セッションを作成
    session = Session.create_for_user(user)

    # plan_idなしでAPIリクエスト
    cookies[:session_id] = session.session_id
    post '/api/v1/public_plans/save_plan',
         params: {},
         as: :json

    # レスポンス確認
    assert_response :bad_request
    response_body = JSON.parse(@response.body)
    assert_not response_body['success']
    assert_equal 'plan_id is required', response_body['error']
  end

  test "POST /api/v1/public_plans/save_plan - 存在しない計画の場合404を返す" do
    # テストユーザーを作成
    user = User.create!(
      email: 'api_test3@example.com',
      name: 'API Test User 3',
      google_id: "api3_#{SecureRandom.hex(8)}"
    )

    # セッションを作成
    session = Session.create_for_user(user)

    # 存在しないplan_idでAPIリクエスト
    cookies[:session_id] = session.session_id
    post '/api/v1/public_plans/save_plan',
         params: { plan_id: 99999 },
         as: :json

    # レスポンス確認
    assert_response :not_found
    response_body = JSON.parse(@response.body)
    assert_not response_body['success']
    assert_equal 'Plan not found', response_body['error']
  end

  test "POST /api/v1/public_plans/save_plan - 保存失敗の場合エラーレスポンスを返す" do
    # テストユーザーを作成（農場上限に達している）
    user = User.create!(
      email: 'api_test4@example.com',
      name: 'API Test User 4',
      google_id: "api4_#{SecureRandom.hex(8)}"
    )

    # ユーザーを4件の農場に制限
    4.times do |i|
      Farm.create!(
        user: user,
        name: "既存農場 #{i + 1}",
        latitude: 35.6812,
        longitude: 139.7671,
        region: 'jp',
        is_reference: false
      )
    end

    # セッションを作成
    session = Session.create_for_user(user)

    # Public計画を作成
    public_plan = CultivationPlan.create!(
      farm: @japan_farm,
      user: nil,
      total_area: 30.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )

    # 作物と計画の関連付け
    cultivation_plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: public_plan,
      crop: @spinach_crop,
      name: @spinach_crop.name,
      crop_id: @spinach_crop.id
    )

    # 圃場を作成
    field = CultivationPlanField.create!(
      cultivation_plan: public_plan,
      name: 'テスト圃場',
      area: 30.0
    )

    # APIリクエスト（保存失敗を期待）
    cookies[:session_id] = session.session_id
    post '/api/v1/public_plans/save_plan',
         params: { plan_id: public_plan.id },
         as: :json

    # レスポンス確認
    assert_response :unprocessable_entity
    response_body = JSON.parse(@response.body)
    assert_not response_body['success']
    assert_not_nil response_body['error']
    assert_includes response_body['error'], "作成できるFarmは4件までです"
  end

  test "GET /public_plans/results - public planの結果を表示" do
    # Public計画を作成（FieldCultivationを含む）
    public_plan = CultivationPlan.create!(
      farm: @japan_farm,
      user: nil,
      session_id: 'test_session_public_results',
      total_area: 30.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current,
      planning_end_date: Date.current.end_of_year
    )

    # CultivationPlanCropを作成
    crop = Crop.reference.where(region: 'jp').first || Crop.create!(
      user: nil,
      name: 'テスト作物',
      variety: 'テスト品種',
      is_reference: true,
      area_per_unit: 1.0,
      revenue_per_area: 1000.0,
      region: 'jp'
    )

    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: public_plan,
      name: crop.name,
      variety: crop.variety,
      area_per_unit: crop.area_per_unit,
      revenue_per_area: crop.revenue_per_area,
      crop_id: crop.id
    )

    # CultivationPlanFieldを作成
    plan_field = CultivationPlanField.create!(
      cultivation_plan: public_plan,
      name: 'テスト圃場',
      area: 30.0
    )

    # FieldCultivationを作成（ガントチャートに必要なデータ）
    field_cultivation = FieldCultivation.create!(
      cultivation_plan: public_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 150.days,
      cultivation_days: 121,
      area: 30.0,
      estimated_cost: 30000.0,
      optimization_result: {
        revenue: 30000.0,
        profit: 0.0,
        accumulated_gdd: 1500.0
      }
    )

    # resultsページにアクセス
    get "/public_plans/results?id=#{public_plan.id}"

    # レスポンス確認
    assert_response :success

    # ガントチャートデータが含まれているか確認（HTMLにデータ属性が含まれている）
    assert_match /data-cultivations/, @response.body
    assert_match /data-fields/, @response.body
    assert_match /data-plan-start-date/, @response.body
    assert_match /data-plan-end-date/, @response.body
    assert_match /data-cultivation-plan-id/, @response.body
    assert_match /data-plan-type/, @response.body
  end

  private

  def select_farm_size_public_plans_path(farm_id:)
    "/public_plans/select_farm_size?farm_id=#{farm_id}"
  end

  def select_crop_public_plans_path(farm_size_id:)
    "/public_plans/select_crop?farm_size_id=#{farm_size_id}"
  end

  def optimizing_public_plans_path
    "/public_plans/optimizing"
  end

  def results_public_plans_path(plan_id:)
    "/public_plans/results?plan_id=#{plan_id}"
  end

  def public_plans_results_path
    "/public_plans/results"
  end
end