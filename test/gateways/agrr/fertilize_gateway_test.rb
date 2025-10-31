# frozen_string_literal: true

require 'test_helper'

module Agrr
  class FertilizeGatewayTest < ActiveSupport::TestCase
    def setup
      @gateway = FertilizeGateway.new
      
      # モックでagrr_serviceをスタブ化
      @mock_service = Minitest::Mock.new
      @gateway.instance_variable_set(:@agrr_service, @mock_service)
    end
    
    test 'should list popular fertilizers' do
      language = 'ja'
      limit = 5
      
      mock_result = [
        { 'name' => '尿素', 'n' => 46 },
        { 'name' => 'リン酸一安', 'n' => 16, 'p' => 20 },
        { 'name' => '硫安', 'n' => 21 },
        { 'name' => '過リン酸石灰', 'p' => 20 },
        { 'name' => '塩化カリ', 'k' => 60 }
      ]
      
      @mock_service.expect(:fertilize_list, mock_result, [
        { language: language, limit: limit, area: nil, json: true }
      ])
      
      result = @gateway.list(language: language, limit: limit)
      
      assert_equal 5, result.length
      assert_equal '尿素', result.first['name']
      assert_equal 46, result.first['n']
      
      @mock_service.verify
    end
    
    test 'should list fertilizers with area parameter' do
      language = 'ja'
      limit = 5
      area = 100
      
      mock_result = [
        { 'name' => '尿素', 'n' => 46, 'recommended_amount' => 200 }
      ]
      
      @mock_service.expect(:fertilize_list, mock_result, [
        { language: language, limit: limit, area: area, json: true }
      ])
      
      result = @gateway.list(language: language, limit: limit, area: area)
      
      assert_equal 1, result.length
      assert_equal '尿素', result.first['name']
      assert_equal 200, result.first['recommended_amount']
      
      @mock_service.verify
    end
    
    test 'should get detailed fertilizer information' do
      name = '尿素'
      
      mock_result = {
        'name' => '尿素',
        'n' => 46,
        'description' => '窒素肥料として広く使用される',
        'usage' => '基肥・追肥に使用可能',
        'application_rate' => '1㎡あたり10-30g'
      }
      
      @mock_service.expect(:fertilize_get, mock_result, [
        { name: name, json: true }
      ])
      
      result = @gateway.get(name: name)
      
      assert_equal '尿素', result['name']
      assert_equal 46, result['n']
      assert result['description'].present?
      
      @mock_service.verify
    end
    
    test 'should recommend fertilizer plan for crop' do
      crop_file = '/tmp/tomato_profile.json'
      
      mock_result = {
        'crop' => 'tomato',
        'recommendations' => [
          {
            'stage' => 'base',
            'n' => 15,
            'p' => 10,
            'k' => 12,
            'fertilizer' => '配合肥料',
            'amount' => 100
          }
        ]
      }
      
      @mock_service.expect(:fertilize_recommend, mock_result, [
        { crop_file: crop_file, json: true }
      ])
      
      result = @gateway.recommend(crop_file: crop_file)
      
      assert_equal 'tomato', result['crop']
      assert_equal 1, result['recommendations'].length
      assert_equal 'base', result['recommendations'].first['stage']
      
      @mock_service.verify
    end
  end
end

