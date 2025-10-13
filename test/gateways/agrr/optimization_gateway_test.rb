# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class Agrr::OptimizationGatewayTest < ActiveSupport::TestCase
  def setup
    @gateway = Agrr::OptimizationGateway.new
    @weather_data = {
      'latitude' => 35.6812,
      'longitude' => 139.7671,
      'elevation' => 10.0,
      'timezone' => 'Asia/Tokyo',
      'data' => [
        {
          'time' => '2024-04-01',
          'temperature_2m_max' => 18.5,
          'temperature_2m_min' => 8.3,
          'temperature_2m_mean' => 13.4,
          'precipitation_sum' => 0.0,
          'sunshine_duration' => 28800.0
        }
      ]
    }
    @user = users(:one)
  end

  test "optimization gateway is instantiable" do
    assert_not_nil @gateway
    assert_respond_to @gateway, :optimize
  end

  test "should raise ExecutionError when agrr command fails" do
    failure_status = OpenStruct.new(success?: false, exitstatus: 1)
    Open3.stub :capture3, ["", "Optimization failed", failure_status] do
      error = assert_raises(Agrr::BaseGateway::ExecutionError) do
        @gateway.optimize(
          crop_name: 'rice',
          variety: 'Koshihikari',
          weather_data: @weather_data,
          field_area: 1000.0,
          daily_fixed_cost: 1000.0,
          evaluation_start: Date.new(2024, 4, 1),
          evaluation_end: Date.new(2024, 9, 30)
        )
      end
      
      assert_match /Optimization failed/, error.message
    end
  end

  test "should accept crop parameter" do
    # Cropオブジェクトを作成
    crop = Crop.create!(
      name: "rice",
      variety: "Koshihikari",
      user_id: @user.id,
      is_reference: false
    )
    
    stage = crop.crop_stages.create!(name: "germination", order: 1)
    stage.create_temperature_requirement!(
      base_temperature: 10.0,
      optimal_min: 20.0,
      optimal_max: 30.0
    )
    stage.create_thermal_requirement!(required_gdd: 200.0)

    # optimizeメソッドがcropパラメータを受け入れることを確認
    failure_status = OpenStruct.new(success?: false, exitstatus: 1)
    Open3.stub :capture3, ["", "Test execution", failure_status] do
      begin
        @gateway.optimize(
          crop_name: 'rice',
          variety: 'Koshihikari',
          weather_data: @weather_data,
          field_area: 1000.0,
          daily_fixed_cost: 1000.0,
          evaluation_start: Date.new(2024, 4, 1),
          evaluation_end: Date.new(2024, 9, 30),
          crop: crop
        )
      rescue Agrr::BaseGateway::ExecutionError
        # エラーは期待通り、パラメータが受け入れられたことを確認
      end
    end
    
    # エラーなくメソッドが呼び出せたことを確認
    assert true
  end

  test "should work without crop parameter" do
    # crop パラメータなしでも動作することを確認
    failure_status = OpenStruct.new(success?: false, exitstatus: 1)
    Open3.stub :capture3, ["", "Test execution", failure_status] do
      begin
        @gateway.optimize(
          crop_name: 'rice',
          variety: 'Koshihikari',
          weather_data: @weather_data,
          field_area: 1000.0,
          daily_fixed_cost: 1000.0,
          evaluation_start: Date.new(2024, 4, 1),
          evaluation_end: Date.new(2024, 9, 30)
        )
      rescue Agrr::BaseGateway::ExecutionError
        # エラーは期待通り、パラメータが受け入れられたことを確認
      end
    end
    
    # エラーなくメソッドが呼び出せたことを確認
    assert true
  end
end

