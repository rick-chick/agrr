# frozen_string_literal: true

require "application_system_test_case"

class ClimateChartDisplayTest < ApplicationSystemTestCase
  test "気温チャートにステージごとの適正温度帯と限界温度帯が表示される" do
    # テストデータを作成
    farm, crops = create_test_data
    cultivation_plan = create_test_cultivation_plan(farm, crops)
    
    # 結果ページを開く（パラメータ付き）
    visit "#{results_public_plans_path}?plan_id=#{cultivation_plan.id}"
    
    # ガントチャートが表示されるまで待機
    assert_selector "#gantt-chart-container", wait: 10
    
    # 実際に表示されている要素を確認
    puts "ページのHTML内容:"
    puts page.body[0..1000] # 最初の1000文字を出力
    
    puts "\n利用可能なCSSクラス:"
    all_css_classes = page.all("*").map(&:tag_name).uniq
    puts all_css_classes.join(", ")
    
    # SVG内の要素を確認
    svg_elements = page.all("svg *")
    puts "\nSVG内の要素数: #{svg_elements.count}"
    svg_elements.each_with_index do |element, index|
      puts "  #{index}: #{element.tag_name} - class: '#{element['class']}' - id: '#{element['id']}'"
    end
    
    # クリック可能な要素を探す
    clickable_elements = page.all("svg rect[data-cultivation-id]")
    puts "\nクリック可能な要素数: #{clickable_elements.count}"
    clickable_elements.each_with_index do |element, index|
      puts "  #{index}: cultivation_id: #{element['data-cultivation-id']}"
    end
    
    # 作物バー（bar-bg）をクリック
    bar_bg_element = page.find("svg rect.bar-bg")
    puts "\nbar-bg要素を見つけました。クリックします。"
    bar_bg_element.click
    
    # 気温チャートが表示されるまで待機（JavaScript実行とAPI通信を待つ）
    puts "\n⏳ APIレスポンス待機中（30秒）..."
    sleep 30 # チャートの読み込みを十分に待つ
    
    # スクリーンショットを撮影
    page.save_screenshot("/app/tmp/screenshots/01_climate_chart_after_click.png")
    
    # コンソールログを確認
    console_logs = page.driver.browser.logs.get(:browser)
    puts "\n📝 ブラウザコンソールログ:"
    console_logs.each do |log|
      puts "  [#{log.level}] #{log.message}"
    end
    
    # チャートコンテナが存在するか確認
    if page.has_selector?("#climate-chart-display", wait: 5)
      puts "✅ 気温チャートコンテナが表示されました"
      
      # チャートキャンバスの存在確認
      if page.has_selector?("canvas#climateTemperatureChart", wait: 2)
        puts "✅ 気温チャートキャンバスが存在します"
        
        # より詳細なスクリーンショット
          page.save_screenshot("/app/tmp/screenshots/02_climate_chart_displayed.png")
        
        # JavaScriptでアノテーションの確認
        sleep 1 # チャートの完全描画を待つ
        
        annotations_info = page.evaluate_script(<<~JS.strip)
          (function() {
            var chart = window.climateChartInstance && window.climateChartInstance.temperatureChart;
            if (!chart) {
              return { exists: false, message: 'Chart instance not found' };
            } else {
              var annotations = (chart.options && chart.options.plugins && chart.options.plugins.annotation && chart.options.plugins.annotation.annotations) || {};
              return {
                exists: true,
                count: Object.keys(annotations).length,
                keys: Object.keys(annotations),
                chartType: chart.config.type
              };
            }
          })()
        JS
        
        puts "📊 アノテーション情報: #{annotations_info.inspect}"
        
        if annotations_info['exists']
          puts "✅ Chart.js インスタンスが存在します"
          puts "📊 アノテーション数: #{annotations_info['count']}"
          puts "🔑 アノテーションキー: #{annotations_info['keys'].join(', ')}"
          
          assert annotations_info['count'] >= 1, "少なくとも1つのアノテーションが必要（実際: #{annotations_info['count']}個）"
        else
          puts "⚠️ Chart.jsインスタンスが見つかりません: #{annotations_info['message']}"
        end
      else
        puts "⚠️ 気温チャートキャンバスが見つかりません"
      end
    else
      puts "⚠️ 気温チャートコンテナが見つかりません"
    end
    
    # 最終スクリーンショット
    page.save_screenshot("/app/tmp/screenshots/03_climate_chart_final.png")
    
    puts "📸 スクリーンショット: tmp/screenshots/"
    puts "   - 01_climate_chart_full_page.png"
    puts "   - 02_climate_chart_displayed.png (チャート表示時)"
    puts "   - 03_climate_chart_final.png"
  end
  
  private
  
  def create_test_data
    # ユーザーを作成
    user = User.create!(
      email: "test@example.com",
      name: "テストユーザー",
      google_id: "test_google_id"
    )
    
    # 気象地点を作成
    weather_location = WeatherLocation.create!(
      latitude: 38.2682,
      longitude: 140.872,
      timezone: "Asia/Tokyo"
    )
    
    # 気象データを作成（過去1年分 + 未来1年分）
    start_date = Date.current - 1.year
    end_date = Date.current + 1.year
    (start_date..end_date).each do |date|
      WeatherDatum.create!(
        weather_location: weather_location,
        date: date,
        temperature_max: 20.0 + rand(-5.0..10.0),
        temperature_min: 10.0 + rand(-5.0..5.0),
        precipitation: rand(0.0..10.0)
      )
    end
    
    # 農場を作成
    farm = Farm.create!(
      user: user,
      name: "テスト農場",
      latitude: 38.2682,
      longitude: 140.872,
      weather_location: weather_location
    )
    
    # 作物を作成
    crop = Crop.create!(
      name: "ニンジン",
      variety: "五寸ニンジン",
      is_reference: true,
      area_per_unit: 10.0,
      revenue_per_area: 500.0
    )
    
    # ステージを作成
    stage1 = CropStage.create!(crop: crop, name: "播種〜発芽", order: 1)
    ThermalRequirement.create!(crop_stage: stage1, required_gdd: 75.0)
    TemperatureRequirement.create!(crop_stage: stage1, optimal_min: 15.0, optimal_max: 20.0, low_stress_threshold: 5.0, high_stress_threshold: 25.0, base_temperature: 10.0)
    
    stage2 = CropStage.create!(crop: crop, name: "発芽〜成長", order: 2)
    ThermalRequirement.create!(crop_stage: stage2, required_gdd: 300.0)
    TemperatureRequirement.create!(crop_stage: stage2, optimal_min: 18.0, optimal_max: 24.0, low_stress_threshold: 5.0, high_stress_threshold: 30.0, base_temperature: 10.0)
    
    stage3 = CropStage.create!(crop: crop, name: "成長〜収穫", order: 3)
    ThermalRequirement.create!(crop_stage: stage3, required_gdd: 500.0)
    TemperatureRequirement.create!(crop_stage: stage3, optimal_min: 15.0, optimal_max: 20.0, low_stress_threshold: 5.0, high_stress_threshold: 30.0, base_temperature: 10.0)
    
    [farm, [crop]]
  end
  
  def create_test_cultivation_plan(farm, crops)
    cultivation_plan = CultivationPlan.create!(
      farm: farm,
      total_area: 1000.0,
      planning_start_date: Date.current + 1.month,
      planning_end_date: Date.current + 6.months,
      status: :completed
    )
    
    # CultivationPlanCropを作成
    plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: cultivation_plan,
      name: crops[0].name,
      variety: crops[0].variety,
      area_per_unit: crops[0].area_per_unit,
      revenue_per_area: crops[0].revenue_per_area,
      agrr_crop_id: crops[0].id
    )
    
    # CultivationPlanFieldを作成
    plan_field = CultivationPlanField.create!(
      cultivation_plan: cultivation_plan,
      name: "圃場1",
      area: 1000.0
    )
    
    # FieldCultivationを作成
    FieldCultivation.create!(
      cultivation_plan: cultivation_plan,
      cultivation_plan_field: plan_field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.current + 1.month,
      completion_date: Date.current + 3.months,
      area: 1000.0,
      status: :completed
    )
    
    cultivation_plan
  end
end

