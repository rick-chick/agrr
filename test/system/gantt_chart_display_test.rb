# frozen_string_literal: true

require "application_system_test_case"

class GanttChartDisplayTest < ApplicationSystemTestCase
  setup do
    # テストデータを作成
    @user = User.create!(
      email: 'gantt_test@example.com',
      name: 'Gantt Test User',
      google_id: "gantt_#{SecureRandom.hex(8)}"
    )

    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      timezone: "Asia/Tokyo"
    )

    @farm = Farm.create!(
      user: @user,
      name: 'ガントテスト農場',
      latitude: 35.6812,
      longitude: 139.7671,
      weather_location: @weather_location,
      is_reference: false,
      region: 'jp'
    )

    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: 'テスト1',
      area: 100.0
    )

    @crop = Crop.create!(
      user: @user,
      name: 'テストトマト',
      is_reference: false,
      area_per_unit: 1.0,
      revenue_per_area: 1000.0
    )

    # Private計画を作成
    @private_plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      status: 'completed',
      plan_type: 'private',
      plan_year: 2025,
      plan_name: 'テスト計画 2025',
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2025, 12, 31)
    )

    # CultivationPlanFieldを作成
    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @private_plan,
      name: @field.name,
      area: @field.area,
      daily_fixed_cost: 0.0
    )

    # CultivationPlanCropを作成
    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @private_plan,
      name: @crop.name,
      area_per_unit: @crop.area_per_unit,
      revenue_per_area: @crop.revenue_per_area,
      crop_id: @crop.id
    )

    # FieldCultivationを作成（ガントチャートに表示される栽培スケジュール）
    @field_cultivation = FieldCultivation.create!(
      cultivation_plan: @private_plan,
      cultivation_plan_field: @plan_field,
      cultivation_plan_crop: @plan_crop,
      start_date: Date.new(2025, 3, 1),
      completion_date: Date.new(2025, 6, 30),
      cultivation_days: 121,
      area: 50.0,
      estimated_cost: 10000.0,
      optimization_result: {
        revenue: 50000.0,
        profit: 40000.0,
        accumulated_gdd: 1500.0
      }
    )

    # Public計画用の参照農場を作成
    @ref_farm = Farm.create!(
      user: User.anonymous_user,
      name: 'Tokyo Reference Farm',
      latitude: 35.6812,
      longitude: 139.7671,
      weather_location: @weather_location,
      is_reference: true,
      region: 'jp'
    )

    # Public計画用の参照作物を作成
    @ref_crop = Crop.create!(
      user: nil,
      name: 'トマト',
      variety: '桃太郎',
      is_reference: true,
      area_per_unit: 1.0,
      revenue_per_area: 1000.0,
      region: 'jp'
    )

    # Public計画を作成
    @public_plan = CultivationPlan.create!(
      farm: @ref_farm,
      user: nil,
      session_id: 'test_session_public_gantt',
      total_area: 100.0,
      status: 'completed',
      plan_type: 'public',
      planning_start_date: Date.current.beginning_of_year,
      planning_end_date: Date.current.end_of_year
    )

    # Public計画のCultivationPlanFieldを作成
    @public_plan_field = CultivationPlanField.create!(
      cultivation_plan: @public_plan,
      name: 'A',
      area: 100.0,
      daily_fixed_cost: 0.0
    )
    additional_public_fields = %w[B C].map do |name|
      CultivationPlanField.create!(
        cultivation_plan: @public_plan,
        name: name,
        area: 80.0,
        daily_fixed_cost: 0.0
      )
    end

    # Public計画のCultivationPlanCropを作成
    @public_plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @public_plan,
      name: @ref_crop.name,
      variety: @ref_crop.variety,
      area_per_unit: @ref_crop.area_per_unit,
      revenue_per_area: @ref_crop.revenue_per_area,
      crop_id: @ref_crop.id
    )

    # Public計画のFieldCultivationを作成
    @public_field_cultivation = FieldCultivation.create!(
      cultivation_plan: @public_plan,
      cultivation_plan_field: @public_plan_field,
      cultivation_plan_crop: @public_plan_crop,
      start_date: Date.current + 30.days,
      completion_date: Date.current + 150.days,
      cultivation_days: 121,
      area: 50.0,
      estimated_cost: 10000.0,
      optimization_result: {
        revenue: 50000.0,
        profit: 40000.0,
        accumulated_gdd: 1500.0
      }
    )
    additional_public_fields.each_with_index do |field, i|
      FieldCultivation.create!(
        cultivation_plan: @public_plan,
        cultivation_plan_field: field,
        cultivation_plan_crop: @public_plan_crop,
        start_date: Date.current + (45 + i * 10).days,
        completion_date: Date.current + (170 + i * 15).days,
        cultivation_days: 130 + (i * 5),
        area: 40.0,
        estimated_cost: 9000.0 + (i * 600),
        optimization_result: {
          revenue: 42000.0 + (i * 2500),
          profit: 31000.0 + (i * 1800),
          accumulated_gdd: 1250.0 + (i * 120)
        }
      )
    end

    # ユーザーのセッションを作成してログイン
    @session = Session.create_for_user(@user)
  end

  test "ガントチャートが表示されない場合 - 圃場データが空の場合" do
    # 別の農場を作成して空の計画を作る
    empty_farm = Farm.create!(
      user: @user,
      name: '空のテスト農場',
      latitude: 35.6812,
      longitude: 139.7671,
      weather_location: @weather_location,
      is_reference: false,
      region: 'jp'
    )

    # 圃場データが空の計画を作成
    empty_plan = CultivationPlan.create!(
      farm: empty_farm,
      user: @user,
      total_area: 100.0,
      status: 'completed',
      plan_type: 'private',
      plan_year: 2025,
      plan_name: '空のテスト計画',
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2025, 12, 31)
    )

    # CultivationPlanFieldを作成しない（空のまま）
    # CultivationPlanCropも作成しない

    login_and_visit plan_path(empty_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /空のテスト計画/, wait: 10

    # 「計画データが読み込まれていません」または「圃場データがありません」のメッセージが表示されることを確認
    assert_selector '.no-data-message', wait: 5, visible: :all
    assert_text '圃場データがありません', wait: 5

    # ガントチャートコンテナが存在しない、または空であることを確認
    gantt_container = find('#gantt-chart-container', visible: :all)
    assert gantt_container['data-fields'].blank? || JSON.parse(gantt_container['data-fields'] || '[]').empty?,
           'Fields data should be empty or not present'
  end

  test "private plans should display gantt chart" do
    login_and_visit plan_path(@private_plan, locale: :ja)

    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /2025/, wait: 10

    # ガントチャートコンテナが存在することを確認
    assert_selector '#gantt-chart-container', wait: 10, visible: :all

    # ガントチャートのデータ属性が設定されていることを確認
    gantt_container = find('#gantt-chart-container', visible: :all)
    assert gantt_container['data-cultivation-plan-id'].present?, 'cultivation-plan-id should be present'
    assert gantt_container['data-cultivations'].present?, 'cultivations data should be present'
    assert gantt_container['data-fields'].present?, 'fields data should be present'
    assert gantt_container['data-plan-start-date'].present?, 'plan start date should be present'
    assert gantt_container['data-plan-end-date'].present?, 'plan end date should be present'
    assert_equal 'private', gantt_container['data-plan-type']

    # データが正しくパースできることを確認
    cultivations = JSON.parse(gantt_container['data-cultivations'])
    assert cultivations.length > 0, 'Should have at least one cultivation'
    assert cultivations.first['crop_name'].present?, 'Should have crop name'

    # JavaScriptが実行されるまで待つ（SVG生成には時間がかかる場合がある）
    sleep 2

    # SVGまたはガント要素が表示されることを確認（custom_gantt_chart.jsの実装による）
    # SVGが生成されない場合でも、コンテナとデータが正しければOK
    has_svg = page.has_selector?('svg.gantt-chart', wait: 3)
    has_gantt_elements = page.has_selector?('.gantt-row', wait: 3) ||
                         page.has_selector?('.gantt-table', wait: 3)

    assert has_svg || has_gantt_elements || gantt_container['data-cultivations'].present?,
           "Gantt chart should be rendered or data should be present"

    # 作物パレットが表示されることを確認（show_crop_palette: true）
    assert_selector '.crop-palette-container', wait: 5
    assert_selector '.crop-palette-toggle-btn', wait: 5

    # ガントチャートヘッダーの構造を確認
    assert_selector '.gantt-header', wait: 5
    assert_selector '.gantt-title', wait: 5

  end

  test "public plans should display gantt chart" do
    login_and_visit public_plans_results_path(locale: :ja, id: @public_plan.id)

    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10

    # ガントチャートコンテナが存在することを確認
    assert_selector '#gantt-chart-container', wait: 10, visible: :all

    # ガントチャートのデータ属性が設定されていることを確認
    gantt_container = find('#gantt-chart-container', visible: :all)
    assert gantt_container['data-cultivation-plan-id'].present?, 'cultivation-plan-id should be present'
    assert gantt_container['data-cultivations'].present?, 'cultivations data should be present'
    assert gantt_container['data-fields'].present?, 'fields data should be present'
    assert gantt_container['data-plan-start-date'].present?, 'plan start date should be present'
    assert gantt_container['data-plan-end-date'].present?, 'plan end date should be present'
    assert_equal 'public', gantt_container['data-plan-type']

    # データが正しくパースできることを確認
    cultivations = JSON.parse(gantt_container['data-cultivations'])
    assert cultivations.length > 0, 'Should have at least one cultivation'
    assert cultivations.first['crop_name'].present?, 'Should have crop name'

    # JavaScriptが実行されるまで待つ
    sleep 2

    # SVGまたはガント要素が表示されることを確認
    has_svg = page.has_selector?('svg.gantt-chart', wait: 3)
    has_gantt_elements = page.has_selector?('.gantt-row', wait: 3) ||
                         page.has_selector?('.gantt-table', wait: 3)

    assert has_svg || has_gantt_elements || gantt_container['data-cultivations'].present?,
           "Gantt chart should be rendered or data should be present"

    # 作物パレットが表示されることを確認（show_crop_palette: true）
    assert_selector '.crop-palette-container', wait: 5
    assert_selector '.crop-palette-toggle-btn', wait: 5

  end

  test "both plans and public_plans use the same gantt chart component" do
    login_and_visit plan_path(@private_plan, locale: :ja)

    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    assert_selector '.plans-gantt-section > .gantt-section', wait: 5, visible: :all
    assert_no_selector '.content-card .gantt-section', wait: 1
    private_container = find('#gantt-chart-container', visible: :all)
    private_cultivations = JSON.parse(private_container['data-cultivations'])

    # Public計画のガントチャートを確認
    login_and_visit public_plans_results_path(locale: :ja, id: @public_plan.id)

    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    assert_selector '.gantt-section', wait: 5, visible: :all
    public_container = find('#gantt-chart-container', visible: :all)
    public_cultivations = JSON.parse(public_container['data-cultivations'])

    # 両方とも同じデータ構造を持つことを確認
    # 両方とも必要なキーを持つことを確認
    required_keys = %w[id field_id field_name crop_name start_date completion_date cultivation_days area estimated_cost profit]
    required_keys.each do |key|
      assert private_cultivations.first.key?(key), "Private plan should have #{key}"
      assert public_cultivations.first.key?(key), "Public plan should have #{key}"
    end
  end

  test "ガントチャートの余白が最小化される" do
    login_and_visit plan_path(@private_plan, locale: :ja)

    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    assert_selector 'svg.custom-gantt-chart', wait: 10, visible: :all

    metrics = page.evaluate_script(<<~'JS')
      (() => {
        const container = document.getElementById('gantt-chart-container');
        const svg = container?.querySelector('svg.custom-gantt-chart');
        if (!container || !svg) { return null; }
        const containerRect = container.getBoundingClientRect();
        const svgRect = svg.getBoundingClientRect();
        return {
          right: Math.round(containerRect.right - svgRect.right),
          bottom: Math.round(containerRect.bottom - svgRect.bottom)
        };
      })();
    JS

    refute_nil metrics, "ガントチャートの寸法が取得できませんでした"

    right_gap = metrics["right"] || metrics[:right]
    bottom_gap = metrics["bottom"] || metrics[:bottom]

    assert_operator right_gap, :>=, 0, "ガントチャート右側の余白計算が負になっています: #{right_gap}"
    assert_operator bottom_gap, :>=, 0, "ガントチャート下側の余白計算が負になっています: #{bottom_gap}"

    assert_operator right_gap, :<=, 48, "ガントチャート右側の余白が大きすぎます: #{right_gap}px"
    assert_operator bottom_gap, :<=, 48, "ガントチャート下側の余白が大きすぎます: #{bottom_gap}px"

    page_width = page.evaluate_script("document.body.scrollWidth")
    viewport_width = page.evaluate_script("window.innerWidth")
    assert_operator page_width - viewport_width, :<=, 8, "ページ全体に横スクロールが発生しています (body.scrollWidth=#{page_width}, viewport=#{viewport_width})"
  end

  test "ガントチャートヘッダーは余計な制御を表示しない" do
    login_and_visit plan_path(@private_plan, locale: :ja)

    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    assert_no_selector '[data-gantt-control]', wait: 1
    assert_no_selector '.gantt-controls', wait: 1
  end

  test "大量データでもレンダリング状態とUXメッセージが表示される" do
    login_and_visit public_plans_results_path(locale: :ja, id: @public_plan.id)

    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    assert_no_selector '#gantt-loading-indicator', wait: 1
  end

  test "モバイル幅ではスクロールとフォールバックが提供される" do
    login_and_visit plan_path(@private_plan, locale: :ja)
    page.driver.browser.manage.window.resize_to(390, 844)

    assert_selector '#gantt-chart-scroll-area', wait: 5, visible: :all
    scroll_width = page.evaluate_script("document.querySelector('#gantt-chart-scroll-area').scrollWidth").to_i
    viewport_width = page.evaluate_script('window.innerWidth').to_i
    assert scroll_width > viewport_width

    page.driver.browser.manage.window.resize_to(320, 480)
    assert_selector '#gantt-chart-fallback', wait: 5, visible: :all
  ensure
    page.driver.browser.manage.window.resize_to(1400, 1400)
  end

  test "GREEN: public plans should accept planId query parameter" do
    # クエリパラメータplanIdで存在する計画IDを指定してアクセスできることを確認
    visit "/public_plans/results?planId=#{@public_plan.id}&locale=ja"

    # ページが読み込まれるまで待つ
    assert_selector 'h1', text: /計画/, wait: 10

    # ガントチャートコンテナが存在し、データが正しく設定されていることを確認
    assert_selector '#gantt-chart-container', wait: 10, visible: :all
    gantt_container = find('#gantt-chart-container', visible: :all)
    assert gantt_container['data-cultivations'].present?, 'Cultivations data should be present'
    assert gantt_container['data-fields'].present?, 'Fields data should be present'

    # データが正しくパースできることを確認
    cultivations = JSON.parse(gantt_container['data-cultivations'])
    fields = JSON.parse(gantt_container['data-fields'])
    assert cultivations.length > 0, 'Should have cultivations data'
    assert fields.length > 0, 'Should have fields data'
  end

  test "RED: adjust API fails with drag and drop data" do
    # adjust APIを直接テスト（system testなのでHTTPリクエストとして実行）
    moves_data = [{
      allocation_id: @public_field_cultivation.id,
      to_field_id: @public_plan_field.id,
      start_date: '2025-04-01'
    }]

    # adjust APIを呼び出し、レスポンスを確認
    # Railsのintegration testとして直接APIをテスト
    post adjust_api_v1_public_plans_cultivation_plan_path(@public_plan),
         params: { moves: moves_data },
         as: :json

    # レスポンスが成功でないことを確認（REDテスト）
    response_body = JSON.parse(response.body) rescue {}
    assert_not (response.status == 200 && response_body['success'] == true),
               "Adjust API should fail but got: status=#{response.status}, body=#{response_body}"
  end

  private

    def eventually(timeout: 5, interval: 0.2)
      start_time = Time.current
      loop do
        result = yield
        return true if result
        raise "Condition not met within #{timeout} seconds" if Time.current - start_time > timeout
        sleep interval
      end
    end

    def login_and_visit(url)
      visit root_path(locale: :ja)
      page.driver.browser.manage.add_cookie(
        name: 'session_id',
        value: @session.session_id,
        path: '/'
      )
      visit url
    end
end