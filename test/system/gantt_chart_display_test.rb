# frozen_string_literal: true

require "application_system_test_case"

class GanttChartDisplayTest < ApplicationSystemTestCase
  setup do
    # 実際のデータを使用（CultivationPlan #27）
    @cultivation_plan = CultivationPlan.find_by(id: 27)
    skip "CultivationPlan #27 が存在しません" unless @cultivation_plan
  end

  test "ガントチャートが正しく表示される" do
    visit_results_page

    # ガントチャートセクションが表示される
    assert_selector ".gantt-section", wait: 10
    assert_text "栽培スケジュール"

    # Frappe Ganttコンテナが存在する
    assert_selector "#gantt-chart-container", wait: 10

    # SVG要素が生成されている
    assert_selector "#gantt-chart-container svg.gantt", wait: 10

    # 作物名がタスクとして表示されている
    within "#gantt-chart-container" do
      # タスクバーが存在する
      assert_selector ".bar-wrapper", minimum: 1, wait: 10
      
      # 作物ラベルが表示されている
      assert_selector ".bar-label", minimum: 1, wait: 5
    end


    # スクリーンショットを撮影
    take_screenshot
  end

  test "ガントチャートに圃場列が表示される" do
    visit_results_page

    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg.gantt", wait: 10

    # 圃場インジケーターが表示されている
    within "#gantt-chart-container" do
      assert_selector ".field-indicator", minimum: 1, wait: 5
    end

    take_screenshot
  end

  test "ガントチャートのタスクをクリックするとポップアップが表示される" do
    visit_results_page

    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg.gantt", wait: 10

    # 最初のタスクバーをクリック
    within "#gantt-chart-container" do
      first_bar = first(".bar-wrapper .bar", wait: 10)
      assert first_bar.present?
      first_bar.click
    end

    # ポップアップが表示される
    assert_selector ".gantt-popup", wait: 5
    assert_selector ".gantt-popup-header"
    assert_selector ".gantt-popup-body"

    take_screenshot
  end

  test "ガントチャートにネストされたスクロールバーがない" do
    visit_results_page

    # ガントチャートコンテナを確認
    assert_selector "#gantt-chart-container", wait: 10

    # コンテナのスタイルを確認（overflow: autoがないこと）
    container = find("#gantt-chart-container")
    
    # JavaScriptでスタイルを取得
    has_nested_scroll = page.evaluate_script(<<~JS)
      const container = document.getElementById('gantt-chart-container');
      const svg = container.querySelector('svg.gantt');
      const containerStyle = window.getComputedStyle(container);
      const svgParentStyle = window.getComputedStyle(svg.parentElement);
      
      // ネストされたスクロールバーがあるかチェック
      const hasNestedScroll = (
        (containerStyle.overflow === 'auto' || containerStyle.overflowX === 'auto') &&
        (svgParentStyle.overflow === 'auto' || svgParentStyle.overflowX === 'auto')
      );
      
      console.log('Container overflow:', containerStyle.overflow);
      console.log('Container overflowX:', containerStyle.overflowX);
      console.log('SVG parent overflow:', svgParentStyle.overflow);
      console.log('Has nested scroll:', hasNestedScroll);
      
      hasNestedScroll;
    JS

    # ネストされたスクロールバーがないことを確認
    assert_not has_nested_scroll, "ガントチャートにネストされたスクロールバーがあります"

    take_screenshot
  end

  test "ガントチャートに作物名のヘッダーが表示される" do
    visit_results_page

    # ガントチャートが読み込まれるまで待機
    assert_selector "#gantt-chart-container svg.gantt", wait: 10

    # 作物名がタスクラベルとして表示されている
    within "#gantt-chart-container" do
      # タスクラベル（作物名）が存在する
      labels = all(".bar-label", wait: 5)
      assert labels.count > 0, "作物名のラベルが表示されていません"
      
      # 少なくとも1つのラベルにテキストが含まれている
      label_texts = labels.map(&:text)
      assert label_texts.any? { |text| text.present? }, "作物名のテキストが空です"
      
      puts "表示されている作物名: #{label_texts.join(', ')}"
    end

    take_screenshot
  end

  test "ガントチャートのデータが正しく読み込まれている" do
    visit_results_page

    # ガントチャートコンテナのデータ属性を確認
    container = find("#gantt-chart-container", wait: 10)
    
    cultivations_data = page.evaluate_script(<<~JS)
      const container = document.getElementById('gantt-chart-container');
      const data = container.dataset.cultivations;
      JSON.parse(data);
    JS

    # データが存在することを確認
    assert cultivations_data.is_a?(Array), "栽培データが配列ではありません"
    assert cultivations_data.count > 0, "栽培データが空です"
    
    # データの構造を確認
    first_cultivation = cultivations_data.first
    assert first_cultivation.key?("id"), "IDが含まれていません"
    assert first_cultivation.key?("crop_name"), "作物名が含まれていません"
    assert first_cultivation.key?("field_name"), "圃場名が含まれていません"
    assert first_cultivation.key?("start_date"), "開始日が含まれていません"
    assert first_cultivation.key?("completion_date"), "終了日が含まれていません"
    
    puts "読み込まれた栽培数: #{cultivations_data.count}"
    puts "最初の栽培: #{first_cultivation['crop_name']} @ #{first_cultivation['field_name']}"

    take_screenshot
  end

  private

  def visit_results_page
    # セッションに計画IDを設定
    visit public_plans_path
    
    # セッション経由で結果画面にアクセス
    page.driver.browser.manage.add_cookie(
      name: 'cultivation_plan_id',
      value: @cultivation_plan.id.to_s
    )
    
    visit public_plans_results_path
  end

  def take_screenshot
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    screenshot_path = Rails.root.join("tmp", "screenshots", "gantt_#{timestamp}.png")
    FileUtils.mkdir_p(screenshot_path.dirname)
    page.save_screenshot(screenshot_path)
    puts "📸 Screenshot saved: #{screenshot_path}"
  end
end

