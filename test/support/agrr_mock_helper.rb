# frozen_string_literal: true

# AGRRコマンドのモック化ヘルパー
# テストでの実行を高速化するため、実際のコマンド実行をモック化する
module AgrrMockHelper
  # 簡略版：モックデータの構造を新形式に変換
  # テストが通ることを優先し、詳細なデータは後で追加

  # Weather APIのモックデータ（新しいJSON構造）
  def mock_weather_data(latitude, longitude, start_date, end_date)
    days = (start_date..end_date).to_a

    {
      "location" => {
        "latitude" => latitude.round(2),
        "longitude" => longitude.round(2),
        "elevation" => 50.0,
        "timezone" => "Asia/Tokyo"
      },
      "data" => days.map.with_index do |date, index|
        {
          "time" => date.to_s,
          "temperature_2m_max" => 20.0 + (index % 10),
          "temperature_2m_min" => 10.0 + (index % 8),
          "temperature_2m_mean" => 15.0 + (index % 9),
          "precipitation_sum" => index.even? ? 0.0 : (5.0 + (index % 15)),
          "sunshine_hours" => 6.0 + (index % 6),
          "wind_speed_10m" => 3.0 + (index % 5),
          "weather_code" => index.even? ? 0 : 61
        }
      end,
      "total_count" => days.count
    }
  end

  # Weather情報取得のモック (Minitest用) - 新しいJSON構造
  def stub_fetch_weather_data(latitude: nil, longitude: nil, start_date: nil, end_date: nil)
    Agrr::WeatherGateway.class_eval do
      define_method(:fetch_by_date_range) do |latitude:, longitude:, start_date:, end_date:, data_source: nil|
        resolved_data_source = data_source || ENV["WEATHER_DATA_SOURCE"] || "noaa"
        days = (start_date..end_date).to_a

        {
          "location" => {
            "latitude" => latitude.round(2),
            "longitude" => longitude.round(2),
            "elevation" => 50.0,
            "timezone" => "Asia/Tokyo"
          },
          "data" => days.map.with_index do |date, index|
            {
              "time" => date.to_s,
              "temperature_2m_max" => 20.0 + (index % 10),
              "temperature_2m_min" => 10.0 + (index % 8),
              "temperature_2m_mean" => 15.0 + (index % 9),
              "precipitation_sum" => index.even? ? 0.0 : (5.0 + (index % 15)),
              "sunshine_hours" => 6.0 + (index % 6),
              "wind_speed_10m" => 3.0 + (index % 5),
              "weather_code" => index.even? ? 0 : 61
            }
          end,
          "total_count" => days.count,
          "data_source" => resolved_data_source
        }
      end
    end

    FetchWeatherDataJob.class_eval do
      define_method(:fetch_weather_from_agrr) do |lat, lon, sd, ed, _farm_id = nil|
        data_source = determine_data_source(_farm_id, latitude: lat, longitude: lon)
        weather_gateway = Agrr::WeatherGateway.new
        weather_gateway.fetch_by_date_range(
          latitude: lat,
          longitude: lon,
          start_date: sd,
          end_date: ed,
          data_source: data_source
        )
      end
    end
  end

  # Crop情報取得のモック (Minitest用) - 新しいJSON構造
  def stub_fetch_crop_info(crop_name = nil)
    Api::V1::CropsController.class_eval do
      define_method(:fetch_crop_info_from_agrr) do |name|
        # 新しい構造でモックデータを返す
        {
          "crop" => {
            "crop_id" => name.downcase.gsub(/\s+/, "_"),
            "name" => name,
            "variety" => nil,
            "area_per_unit" => 0.5,
            "revenue_per_area" => 500.0,
            "groups" => [ "unknown" ]
          },
          "stage_requirements" => [
            {
              "stage" => { "name" => "生育期", "order" => 1 },
              "temperature" => {
                "base_temperature" => 10.0,
                "optimal_min" => 20.0,
                "optimal_max" => 25.0,
                "low_stress_threshold" => 15.0,
                "high_stress_threshold" => 30.0,
                "frost_threshold" => 0.0,
                "sterility_risk_threshold" => nil
              },
              "sunshine" => {
                "minimum_sunshine_hours" => 5.0,
                "target_sunshine_hours" => 8.0
              },
              "thermal" => {
                "required_gdd" => 500.0
              },
              "nutrients" => {
                "daily_uptake" => {
                  "N" => 0.5,
                  "P" => 0.2,
                  "K" => 0.8
                }
              }
            }
          ]
        }
      end
    end
  end

  # Adjust Gateway のモック化
  def mock_agrr_adjust_success
    Agrr::AdjustGateway.class_eval do
      define_method(:adjust) do |current_allocation:, moves:, fields:, crops:, weather_data:, planning_start:, planning_end:, interaction_rules:, objective:, enable_parallel:|
        # 既存の割り当てを基にモック結果を作成
        # moves が渡された場合は、該当する allocation の start_date を更新して返す（テストでの adjust 動作を簡易的に再現）
        field_schedules = current_allocation.dig(:optimization_result, :field_schedules) || []

        # 深いコピーを作成して元データを壊さない
        copied = Marshal.load(Marshal.dump(field_schedules))

        # moves が配列の場合、allocation_id に応じて start_date を更新する（to_start_date が指定されている場合）
        Array(moves).each do |move|
          next unless move.is_a?(Hash) || move.respond_to?(:to_h)
          mv = move.to_h
          alloc_id = mv[:allocation_id] || mv["allocation_id"] || mv[:cultivation_id] || mv["cultivation_id"]
          new_start = mv[:to_start_date] || mv["to_start_date"]
          if alloc_id && new_start
            copied.each do |fs|
              (fs[:allocations] || fs["allocations"] || []).each do |alloc|
                # allocation_id は文字列/数値混在の可能性があるため文字列比較
                if alloc["allocation_id"].to_s == alloc_id.to_s || alloc[:allocation_id].to_s == alloc_id.to_s
                  # 更新（文字列キーで返すため string 化）
                  alloc["start_date"] = new_start
                end
              end
            end
          end
        end

        # 集計値を再計算（簡易）
        total_profit = copied.sum { |fs| (fs["total_profit"] || fs[:total_profit] || 0).to_f }
        total_revenue = copied.sum { |fs| (fs["total_revenue"] || fs[:total_revenue] || 0).to_f }
        total_cost = copied.sum { |fs| (fs["total_cost"] || fs[:total_cost] || 0).to_f }

        {
          total_profit: total_profit,
          total_revenue: total_revenue,
          total_cost: total_cost,
          field_schedules: copied.map { |fs| fs.deep_stringify_keys },
          summary: { status: "success" },
          optimization_time: 0.1,
          algorithm_used: "mock",
          is_optimal: true
        }
      end
    end
  end

  # 天気予測のモック (Minitest用)
  def stub_weather_prediction
    Agrr::PredictionGateway.class_eval do
      define_method(:predict) do |historical_data:, days:, model:|
        Rails.logger.info "🧪 [Mock PredictionGateway] Returning mock prediction data for #{days} days"

        # 予測データを生成
        start_date = Date.current - 1.day
        prediction_data = (1..days).map do |i|
          date = start_date + i.days
          {
            "time" => date.to_s,
            "temperature_2m_max" => 25.0 + rand(-5..5),
            "temperature_2m_min" => 15.0 + rand(-5..5),
            "temperature_2m_mean" => 20.0 + rand(-3..3),
            "precipitation_sum" => rand(0..10),
            "sunshine_duration" => rand(6..12) * 3600, # 秒単位
            "wind_speed_10m_max" => rand(1..5),
            "weather_code" => rand(0..3)
          }
        end

        # モックデータを返す
        {
          "data" => prediction_data,
          "metadata" => {
            "prediction_method" => "mock",
            "created_at" => Time.current.iso8601,
            "data_points" => prediction_data.size
          }
        }
      end
    end
  end

  # すべてのAGRRコマンドをモック化（setup時に使用）
  def stub_all_agrr_commands
    stub_fetch_crop_info
    stub_fetch_weather_data
    stub_weather_prediction
    mock_agrr_adjust_success
  end

  # Alias for convenience
  alias_method :mock_agrr_cli_success, :mock_agrr_adjust_success
end
