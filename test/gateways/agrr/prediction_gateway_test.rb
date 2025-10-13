# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class Agrr::PredictionGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Agrr::PredictionGateway.new
    @historical_data = {
      'latitude' => 35.6812,
      'longitude' => 139.7671,
      'elevation' => 10.0,
      'timezone' => 'Asia/Tokyo',
      'data' => [
        {
          'time' => '2024-01-01',
          'temperature_2m_max' => 10.5,
          'temperature_2m_min' => 2.3,
          'temperature_2m_mean' => 6.4,
          'precipitation_sum' => 0.0,
          'sunshine_duration' => 25200.0
        }
      ]
    }
  end

  test "should raise ParseError when output file is empty" do
    # agrr predictコマンドが空のファイルを出力する場合をシミュレート
    # Open3.capture3をモックして、成功を返すが出力ファイルが空の場合
    success_status = OpenStruct.new(success?: true, exitstatus: 0)
    Open3.stub :capture3, ["", "", success_status] do
      error = assert_raises(Agrr::BaseGateway::ParseError) do
        @gateway.predict(historical_data: @historical_data, days: 365)
      end
      
      assert_match /Prediction output file is empty/, error.message
    end
  end

  test "should raise ParseError when output file contains invalid JSON" do
    skip "Complex to mock file I/O - tested via integration test"
  end

  test "should raise ExecutionError when agrr command fails" do
    # agrr predictコマンドが失敗する場合をシミュレート
    failure_status = OpenStruct.new(success?: false, exitstatus: 1)
    Open3.stub :capture3, ["", "Command execution failed", failure_status] do
      error = assert_raises(Agrr::BaseGateway::ExecutionError) do
        @gateway.predict(historical_data: @historical_data, days: 365)
      end
      
      assert_match /Command execution failed/, error.message
    end
  end

  test "should return prediction data when command succeeds" do
    skip "Requires actual agrr command or complex mock"
  end

  test "prediction gateway is instantiable" do
    # 基本的なインスタンス化のテスト
    assert_not_nil @gateway
    assert_respond_to @gateway, :predict
  end
end

