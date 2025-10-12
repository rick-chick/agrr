# frozen_string_literal: true

# AGRRコマンドのモック化ヘルパー
# テストでの実行を高速化するため、実際のコマンド実行をモック化する
module AgrrMockHelper
  # Crop情報のモックデータ
  MOCK_CROP_DATA = {
    'キャベツ' => {
      'success' => true,
      'data' => {
        'crop_id' => 'キャベツ',
        'crop_name' => 'キャベツ',
        'variety' => nil,
        'area_per_unit' => 0.5,
        'revenue_per_area' => 600.0,
        'stages' => [
          {
            'name' => '育苗期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 5.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -5.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 4.0,
              'target_sunshine_hours' => 6.0
            },
            'thermal' => {
              'required_gdd' => 200.0
            }
          },
          {
            'name' => '結球期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -5.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 600.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -5.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 200.0
            }
          }
        ]
      }
    },
    'ナス' => {
      'success' => true,
      'data' => {
        'crop_id' => 'ナス',
        'crop_name' => 'ナス',
        'variety' => nil,
        'area_per_unit' => 0.5,
        'revenue_per_area' => 800.0,
        'stages' => [
          {
            'name' => '育苗期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 12.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 300.0
            }
          },
          {
            'name' => '定植期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 12.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 32.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          },
          {
            'name' => '生育期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 15.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 32.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 10.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 4,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 12.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 32.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          }
        ]
      }
    },
    'トマト' => {
      'success' => true,
      'data' => {
        'crop_id' => 'トマト',
        'crop_name' => 'トマト',
        'variety' => nil,
        'area_per_unit' => 0.3,
        'revenue_per_area' => 1200.0,
        'stages' => [
          {
            'name' => '育苗期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 25.0,
              'low_stress_threshold' => 13.0,
              'high_stress_threshold' => 32.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 250.0
            }
          },
          {
            'name' => '生育期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 15.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 35.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 10.0
            },
            'thermal' => {
              'required_gdd' => 1000.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 13.0,
              'high_stress_threshold' => 32.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 35.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          }
        ]
      }
    },
    'ピーマン' => {
      'success' => true,
      'data' => {
        'crop_id' => 'ピーマン',
        'crop_name' => 'ピーマン',
        'variety' => nil,
        'area_per_unit' => 0.4,
        'revenue_per_area' => 900.0,
        'stages' => [
          {
            'name' => '育苗期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 15.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 300.0
            }
          },
          {
            'name' => '生育・収穫期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 10.0,
              'optimal_min' => 20.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 15.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => 0.0,
              'sterility_risk_threshold' => 35.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 10.0
            },
            'thermal' => {
              'required_gdd' => 1500.0
            }
          }
        ]
      }
    },
    'にんじん' => {
      'success' => true,
      'data' => {
        'crop_id' => 'にんじん',
        'crop_name' => 'にんじん',
        'variety' => nil,
        'area_per_unit' => 0.2,
        'revenue_per_area' => 500.0,
        'stages' => [
          {
            'name' => '発芽期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 25.0,
              'low_stress_threshold' => 7.0,
              'high_stress_threshold' => 30.0,
              'frost_threshold' => -2.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 4.0,
              'target_sunshine_hours' => 6.0
            },
            'thermal' => {
              'required_gdd' => 150.0
            }
          },
          {
            'name' => '生育期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -2.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -2.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 200.0
            }
          }
        ]
      }
    },
    'ほうれん草' => {
      'success' => true,
      'data' => {
        'crop_id' => 'ほうれん草',
        'crop_name' => 'ほうれん草',
        'variety' => nil,
        'area_per_unit' => 0.15,
        'revenue_per_area' => 700.0,
        'stages' => [
          {
            'name' => '発芽期',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 7.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -5.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 4.0,
              'target_sunshine_hours' => 6.0
            },
            'thermal' => {
              'required_gdd' => 100.0
            }
          },
          {
            'name' => '生育期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -8.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 400.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 4.0,
              'optimal_min' => 15.0,
              'optimal_max' => 20.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 25.0,
              'frost_threshold' => -8.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 5.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 150.0
            }
          }
        ]
      }
    },
    '存在しない作物XYZ' => {
      'success' => true,
      'data' => {
        'crop_id' => 'xyz',
        'crop_name' => 'XYZ',
        'variety' => nil,
        'area_per_unit' => 0.5,
        'revenue_per_area' => 1200.5,
        'stages' => [
          {
            'name' => '播種〜発芽',
            'order' => 1,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 10.0,
              'optimal_max' => 25.0,
              'low_stress_threshold' => 3.0,
              'high_stress_threshold' => 30.0,
              'frost_threshold' => -2.0,
              'sterility_risk_threshold' => nil
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 4.0,
              'target_sunshine_hours' => 8.0
            },
            'thermal' => {
              'required_gdd' => 100.0
            }
          },
          {
            'name' => '成長期',
            'order' => 2,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 15.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => -1.0,
              'sterility_risk_threshold' => 32.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 10.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          },
          {
            'name' => '収穫期',
            'order' => 3,
            'temperature' => {
              'base_temperature' => 5.0,
              'optimal_min' => 15.0,
              'optimal_max' => 30.0,
              'low_stress_threshold' => 10.0,
              'high_stress_threshold' => 35.0,
              'frost_threshold' => -1.0,
              'sterility_risk_threshold' => 32.0
            },
            'sunshine' => {
              'minimum_sunshine_hours' => 6.0,
              'target_sunshine_hours' => 10.0
            },
            'thermal' => {
              'required_gdd' => 800.0
            }
          }
        ]
      }
    }
  }.freeze

  # デフォルトの作物データ（登録されていない作物名の場合）
  DEFAULT_CROP_DATA = {
    'success' => true,
    'data' => {
      'crop_id' => 'unknown',
      'crop_name' => 'Unknown Crop',
      'variety' => nil,
      'area_per_unit' => 0.5,
      'revenue_per_area' => 500.0,
      'stages' => [
        {
          'name' => '生育期',
          'order' => 1,
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
  }.freeze

  # Weather APIのモックデータ
  def mock_weather_data(latitude, longitude, start_date, end_date)
    days = (start_date..end_date).to_a
    
    {
      'success' => true,
      'data' => {
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
        end
      }
    }
  end

  # Crop情報取得のモック (Minitest用)
  def stub_fetch_crop_info(crop_name = nil)
    # モックの定義
    Api::V1::CropsController.class_eval do
      define_method(:fetch_crop_info_from_agrr) do |name|
        mock_crop_data = AgrrMockHelper::MOCK_CROP_DATA[name] || AgrrMockHelper::DEFAULT_CROP_DATA.dup.tap do |data|
          data['data']['crop_id'] = name.downcase.gsub(/\s+/, '_')
          data['data']['crop_name'] = name
        end
        mock_crop_data
      end
    end
  end

  # Weather情報取得のモック (Minitest用)
  def stub_fetch_weather_data(latitude: nil, longitude: nil, start_date: nil, end_date: nil)
    # モックの定義
    FetchWeatherDataJob.class_eval do
      define_method(:fetch_weather_from_agrr) do |lat, lon, sd, ed|
        days = (sd..ed).to_a
        
        {
          'success' => true,
          'data' => {
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
            end
          }
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

