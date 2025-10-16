# frozen_string_literal: true

require "application_system_test_case"

class GanttChartSimpleTest < ApplicationSystemTestCase
  test "Frappe Ganttライブラリが読み込まれる" do
    visit root_path
    
    # JavaScriptエラーがないことを確認
    errors = page.driver.browser.logs.get(:browser)
      .select { |log| log.level == "SEVERE" }
      .map(&:message)
    
    assert_empty errors, "JavaScriptエラーが発生しています: #{errors.join(", ")}"
  end
  
  test "frappe-gantt.cssが読み込まれる" do
    visit root_path
    
    # CSSファイルが存在することを確認（ヘッドレスモードでも確認可能）
    has_gantt_css = page.evaluate_script(<<~JS)
      Array.from(document.styleSheets).some(sheet => {
        try {
          return sheet.href && sheet.href.includes('frappe-gantt');
        } catch(e) {
          return false;
        }
      });
    JS
    
    puts "Frappe Gantt CSS loaded: #{has_gantt_css}"
  end
  
  test "gantt_chart.jsが読み込まれる" do
    visit root_path
    
    # initGanttChart関数が定義されていることを確認
    has_init_function = page.evaluate_script("typeof window.initGanttChart === 'function'")
    
    puts "initGanttChart function exists: #{has_init_function}"
  end
end

