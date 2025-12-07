# frozen_string_literal: true

require 'test_helper'

class Farms::WeatherDataControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as @user

    @farm = create(:farm, user: @user)
    @weather_location = create(:weather_location)
    @farm.update!(weather_location: @weather_location)
  end

  test '予測要求は過去2年分未満のデータなら422を返す' do
    # 730日未満の履歴データ（現状の365閾値では通ってしまう）
    500.times do |i|
      create(:weather_datum,
             weather_location: @weather_location,
             date: Date.today - i.days,
             temperature_max: 25.0,
             temperature_min: 15.0,
             temperature_mean: 20.0,
             precipitation: 0.0)
    end

    get farm_weather_data_path(@farm, predict: 'true'), headers: { 'Accept' => 'application/json' }

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal false, body['success']
    assert_equal I18n.t('farms.weather_data.insufficient_historical_data'), body['message']
  end
end


