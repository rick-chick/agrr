# frozen_string_literal: true

require "application_system_test_case"
require "timeout"

class PrivatePlanDragAndDropTest < ApplicationSystemTestCase
  setup do
    @user = User.create!(
      email: "drag_drop_test@example.com",
      name: "DragDrop User",
      google_id: "dragdrop_#{SecureRandom.hex(8)}"
    )

    @weather_location = WeatherLocation.create!(
      latitude: 35.6812,
      longitude: 139.7671,
      timezone: "Asia/Tokyo"
    )

    ensure_weather_data(@weather_location)

    @farm = Farm.create!(
      user: @user,
      name: "ドラッグドロップ農場",
      latitude: 35.6812,
      longitude: 139.7671,
      weather_location: @weather_location,
      is_reference: false,
      region: "jp"
    )

    @field = Field.create!(
      farm: @farm,
      user: @user,
      name: "圃場A",
      area: 100.0
    )

    @crop = FactoryBot.create(
      :crop,
      :with_stages,
      user: @user,
      name: "テストトマト",
      variety: "試験品種",
      is_reference: false,
      area_per_unit: 10.0,
      revenue_per_area: 1000.0
    )

    @plan = CultivationPlan.create!(
      farm: @farm,
      user: @user,
      total_area: 100.0,
      status: "completed",
      plan_type: "private",
      plan_year: 2025,
      plan_name: "DDテスト計画",
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2025, 12, 31)
    )

    @plan_field = CultivationPlanField.create!(
      cultivation_plan: @plan,
      name: @field.name,
      area: @field.area,
      daily_fixed_cost: 0.0
    )

    @plan_crop = CultivationPlanCrop.create!(
      cultivation_plan: @plan,
      crop: @crop,
      name: @crop.name,
      variety: @crop.variety,
      area_per_unit: @crop.area_per_unit,
      revenue_per_area: @crop.revenue_per_area
    )

    @session = Session.create_for_user(@user)
  end

  test "ユーザーは作物をガントチャートにドラッグ&ドロップできる" do
    visit root_path(locale: :ja)

    page.driver.browser.manage.add_cookie(
      name: "session_id",
      value: @session.session_id,
      path: "/"
    )

    visit plan_path(@plan, locale: :ja)

    assert_selector "#gantt-chart-container", wait: 10
    assert_selector "svg.custom-gantt-chart", wait: 10
    assert_selector ".crop-palette-card", wait: 10

    # パレットが閉じていれば開いておく
    page.execute_script(<<~JS)
      const panel = document.getElementById("crop-palette-panel");
      if (panel && panel.classList.contains("collapsed")) {
        panel.classList.remove("collapsed");
      }
    JS

    instrument_fetch_for_add_crop
    simulate_drag_from_palette_to_chart

    wait_for_add_crop_request

    result = page.evaluate_script("window.__addCropCalls[window.__addCropCalls.length - 1]")

    assert result, "add_cropリクエストが記録されていません"
    assert_equal 200, result["status"], "add_crop APIが成功ステータスを返しませんでした: #{result}"
    assert_equal true, result.dig("data", "success"), "add_crop APIのレスポンスが成功を示していません: #{result}"
  end

  private

  def instrument_fetch_for_add_crop
    page.execute_script(<<~JS)
      (function() {
        if (window.__addCropInstrumented) { return; }
        window.__addCropInstrumented = true;
        window.__addCropCalls = [];
        const originalFetch = window.fetch;
        window.fetch = function() {
          const args = Array.from(arguments);
          const request = args[0];
          const url = typeof request === "string" ? request : (request && request.url);
          return originalFetch.apply(this, args).then(function(response) {
            if (url && url.includes("/add_crop")) {
              const record = { url: url, status: response.status };
              try {
                response.clone().json().then(function(data) {
                  record.data = data;
                  window.__addCropCalls.push(record);
                }).catch(function(parseError) {
                  record.data = { parse_error: parseError && parseError.message };
                  window.__addCropCalls.push(record);
                });
              } catch (cloneError) {
                record.data = { clone_error: cloneError && cloneError.message };
                window.__addCropCalls.push(record);
              }
            }
            return response;
          });
        };
      })();
    JS
  end

  def simulate_drag_from_palette_to_chart
    page.execute_script(<<~JS)
      (function() {
        const card = document.querySelector(".crop-palette-card");
        const svg = document.querySelector("svg.custom-gantt-chart");
        if (!card || !svg) {
          window.__dragError = "elements_not_found";
          return;
        }
        const cardRect = card.getBoundingClientRect();
        const svgRect = svg.getBoundingClientRect();

        const startX = cardRect.left + cardRect.width / 2;
        const startY = cardRect.top + cardRect.height / 2;
        const dropX = svgRect.left + (svgRect.width * 0.3);
        const dropY = svgRect.top + 100;

        card.dispatchEvent(new MouseEvent("mousedown", {
          clientX: startX,
          clientY: startY,
          bubbles: true
        }));

        document.dispatchEvent(new MouseEvent("mousemove", {
          clientX: dropX,
          clientY: dropY,
          bubbles: true
        }));

        document.dispatchEvent(new MouseEvent("mouseup", {
          clientX: dropX,
          clientY: dropY,
          bubbles: true
        }));
      })();
    JS

    drag_error = page.evaluate_script("window.__dragError")
    assert_nil drag_error, "ドラッグシミュレーションでエラーが発生しました: #{drag_error}"
  end

  def wait_for_add_crop_request
    Timeout.timeout(10) do
      loop do
        calls = page.evaluate_script("window.__addCropCalls ? window.__addCropCalls.length : 0")
        break if calls.to_i.positive?
        sleep 0.2
      end
    end
  rescue Timeout::Error
    browser_logs = page.driver.browser.manage.logs.get(:browser)
    flunk "add_cropリクエストが送信されませんでした。ブラウザログ: #{browser_logs}"
  end

  def ensure_weather_data(weather_location)
    existing_count = WeatherDatum.where(weather_location: weather_location).count
    return if existing_count >= 6000

    start_date = Date.current - 20.years
    end_date = Date.current
    records = []

    (start_date..end_date).each do |date|
      records << {
        weather_location_id: weather_location.id,
        date: date,
        temperature_max: 26.0,
        temperature_min: 14.0,
        temperature_mean: 20.0,
        precipitation: 2.0,
        sunshine_hours: 8.0,
        wind_speed: 3.0,
        weather_code: 1,
        created_at: Time.current,
        updated_at: Time.current
      }

      if records.length >= 1000
        WeatherDatum.insert_all(records)
        records.clear
      end
    end

    WeatherDatum.insert_all(records) if records.any?
  end
end

