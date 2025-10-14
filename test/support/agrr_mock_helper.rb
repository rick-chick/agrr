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
      'location' => {
        'latitude' => latitude.round(2),
        'longitude' => longitude.round(2),
        'elevation' => 50.0,
        'timezone' => 'Asia/Tokyo'
      },
      'data' => days.map.with_index do |date, index|
        {
          'time' => date.to_s,
          'temperature_2m_max' => 20.0 + (index % 10),
          'temperature_2m_min' => 10.0 + (index % 8),
          'temperature_2m_mean' => 15.0 + (index % 9),
          'precipitation_sum' => index.even? ? 0.0 : (5.0 + (index % 15)),
          'sunshine_hours' => 6.0 + (index % 6),
          'wind_speed_10m' => 3.0 + (index % 5),
          'weather_code' => index.even? ? 0 : 61
        }
      end,
      'total_count' => days.count
    }
  end

  # Weather情報取得のモック (Minitest用) - 新しいJSON構造
  def stub_fetch_weather_data(latitude: nil, longitude: nil, start_date: nil, end_date: nil)
    FetchWeatherDataJob.class_eval do
      define_method(:fetch_weather_from_agrr) do |lat, lon, sd, ed|
        days = (sd..ed).to_a
        
        {
          'location' => {
            'latitude' => lat.round(2),
            'longitude' => lon.round(2),
            'elevation' => 50.0,
            'timezone' => 'Asia/Tokyo'
          },
          'data' => days.map.with_index do |date, index|
            {
              'time' => date.to_s,
              'temperature_2m_max' => 20.0 + (index % 10),
              'temperature_2m_min' => 10.0 + (index % 8),
              'temperature_2m_mean' => 15.0 + (index % 9),
              'precipitation_sum' => index.even? ? 0.0 : (5.0 + (index % 15)),
              'sunshine_hours' => 6.0 + (index % 6),
              'wind_speed_10m' => 3.0 + (index % 5),
              'weather_code' => index.even? ? 0 : 61
            }
          end,
          'total_count' => days.count
        }
      end
    end
  end

  # Crop情報取得のモック (Minitest用) - 新しいJSON構造
  def stub_fetch_crop_info(crop_name = nil)
    Api::V1::CropsController.class_eval do
      define_method(:fetch_crop_info_from_agrr) do |name|
        # 新しい構造でモックデータを返す
        {
          'crop' => {
            'crop_id' => name.downcase.gsub(/\s+/, '_'),
            'name' => name,
            'variety' => nil,
            'area_per_unit' => 0.5,
            'revenue_per_area' => 500.0,
            'groups' => ['unknown']
          },
          'stage_requirements' => [
            {
              'stage' => { 'name' => '生育期', 'order' => 1 },
              'temperature' => {
                'base_temperature' => 10.0,
                'optimal_min' => 20.0,
                'optimal_max' => 25.0,
                'low_stress_threshold' => 15.0,
                'high_stress_threshold' => 30.0,
                'frost_threshold' => 0.0,
                'sterility_risk_threshold' => nil
              },
              'sunshine' => {
                'minimum_sunshine_hours' => 5.0,
                'target_sunshine_hours' => 8.0
              },
              'thermal' => {
                'required_gdd' => 500.0
              }
            }
          ]
        }
      end
    end
  end

  # すべてのAGRRコマンドをモック化（setup時に使用）
  def stub_all_agrr_commands
    stub_fetch_crop_info
    stub_fetch_weather_data
  end
end
