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
    # テストの高速化: 実際に大量レコードを DB に作成する代わりに
    # association をスタブして過去データが不足している状況を模擬する
    fake_rel = Object.new
    def fake_rel.where(*); self; end
    def fake_rel.order(*); self; end
    # ActiveRecord の where.not チェーンに対応するためのメソッド
    def fake_rel.not(*); self; end
    # 十分に少ない件数を返す（過去2年分: 約730日を下回る想定）
    def fake_rel.count; 500; end

    @weather_location.stub(:weather_data, fake_rel) do
      get farm_weather_data_path(@farm, predict: 'true'), headers: { 'Accept' => 'application/json' }

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal false, body['success']
      assert_equal I18n.t('farms.weather_data.insufficient_historical_data'), body['message']
    end
  end
end


