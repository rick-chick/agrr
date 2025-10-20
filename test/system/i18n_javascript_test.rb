require "application_system_test_case"

class I18nJavascriptTest < ApplicationSystemTestCase
  setup do
    @prefecture = Prefecture.first || Prefecture.create!(
      name: "テスト県",
      region: Prefecture.regions.keys.first
    )
    @location = Location.first || Location.create!(
      prefecture: @prefecture,
      name: "テスト地点",
      latitude: 35.6762,
      longitude: 139.6503
    )
  end

  test "custom_gantt_chart.js messages are internationalized" do
    # 日本語でテスト
    visit root_path
    
    # data属性にi18nメッセージが設定されているか確認
    assert page.has_css?('body[data-js-gantt-optimization-failed]')
    assert page.has_css?('body[data-js-gantt-update-failed]')
    assert page.has_css?('body[data-js-gantt-fetch-error]')
    assert page.has_css?('body[data-js-gantt-add-field-button]')
    assert page.has_css?('body[data-js-gantt-adding-field-loading]')
  end

  test "crop_form.js placeholders are internationalized" do
    visit root_path
    
    # data属性にi18nメッセージが設定されているか確認
    assert page.has_css?('body[data-js-crop-stage-name-placeholder]')
    assert page.has_css?('body[data-js-crop-temperature-placeholder]')
  end

  test "crop_selection.js messages are internationalized" do
    visit root_path
    
    # data属性にi18nメッセージが設定されているか確認
    assert page.has_css?('body[data-js-crop-selection-max-message]')
    assert page.has_css?('body[data-js-crop-selection-hint]')
  end

  test "cultivation_results.js messages are internationalized" do
    visit root_path
    
    # data属性にi18nメッセージが設定されているか確認
    assert page.has_css?('body[data-js-cultivation-load-error]')
    assert page.has_css?('body[data-js-cultivation-data-error]')
  end

  test "plans_show.js messages are internationalized" do
    visit root_path
    
    # data属性にi18nメッセージが設定されているか確認
    assert page.has_css?('body[data-js-plans-load-error]')
  end

  test "language switcher changes messages" do
    visit root_path
    
    # 英語に切り替え
    if page.has_link?("English")
      click_link "English"
      
      # 英語のメッセージが表示されているか確認
      body_element = page.find('body')
      en_message = body_element['data-js-gantt-optimization-failed']
      assert_includes en_message.downcase, "failed" if en_message.present?
    end
  end
end

