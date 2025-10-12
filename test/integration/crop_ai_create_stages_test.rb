# frozen_string_literal: true

require "test_helper"

class CropAiCreateStagesTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:two)  # non-admin user
    sign_in_as(@user)
  end

  test "AI create saves crop stages" do
    crop_name = "ナス"
    
    post '/api/v1/crops/ai_create',
         params: { name: crop_name },
         as: :json

    assert_response :created
    
    json_response = JSON.parse(response.body)
    crop = Crop.find(json_response['crop_id'])
    
    # 生育ステージが保存されているか
    assert crop.crop_stages.count > 0, "Should have crop stages"
    
    # 各ステージに要件が保存されているか
    crop.crop_stages.each do |stage|
      assert_not_nil stage.name
      assert_not_nil stage.order
      
      # 温度要件（多くの作物で設定されている）
      if stage.temperature_requirement
        assert stage.temperature_requirement.base_temperature.present?
      end
      
      # 日照要件
      if stage.sunshine_requirement
        assert stage.sunshine_requirement.minimum_sunshine_hours.present?
      end
      
      # 熱量要件
      if stage.thermal_requirement
        assert stage.thermal_requirement.required_gdd.present?
      end
    end
  end

  test "AI create returns stages_count in response" do
    post '/api/v1/crops/ai_create',
         params: { name: "ピーマン" },
         as: :json

    assert_response :created
    
    json_response = JSON.parse(response.body)
    assert json_response['stages_count'].present?
    assert json_response['stages_count'] > 0
  end

  test "existing crop (reference) is updated with latest agrr data" do
    # fixtureに既に「トマト」が参照作物として存在している
    reference_crop = crops(:tomato)
    
    # AI実行前にステージを削除（更新されることを確認するため）
    reference_crop.crop_stages.destroy_all
    
    # AI作成を試みる（agrrコマンドを実行して更新）
    assert_no_difference('Crop.count') do
      post '/api/v1/crops/ai_create',
           params: { name: "トマト" },
           as: :json
    end

    assert_response :ok  # 更新なので ok
    
    json_response = JSON.parse(response.body)
    assert_equal true, json_response['success']
    assert_equal reference_crop.id, json_response['crop_id']
    assert_equal true, json_response['is_reference']
    assert_match /更新/, json_response['message']
    
    # agrrから取得した最新データで更新されているか
    reference_crop.reload
    assert_not_nil reference_crop.area_per_unit
    assert_not_nil reference_crop.revenue_per_area
    assert reference_crop.area_per_unit > 0
    assert reference_crop.revenue_per_area > 0
    
    # 生育ステージも更新されているか
    assert reference_crop.crop_stages.count > 0, "Stages should be updated"
    assert_equal reference_crop.crop_stages.count, json_response['stages_count']
    
    # ステージに要件が保存されているか確認
    first_stage = reference_crop.crop_stages.order(:order).first
    assert_not_nil first_stage.temperature_requirement
    assert_not_nil first_stage.sunshine_requirement
    assert_not_nil first_stage.thermal_requirement
  end
  
  test "existing crop (user owned) is updated with latest agrr data" do
    # ユーザーが既に「ほうれん草」を作成している
    user_crop = Crop.create!(
      name: "ほうれん草",
      user_id: @user.id,
      is_reference: false,
      area_per_unit: 0.05,
      revenue_per_area: 300
    )
    
    # AI実行 → 既存のユーザー作物を更新
    assert_no_difference('Crop.count') do
      post '/api/v1/crops/ai_create',
           params: { name: "ほうれん草" },
           as: :json
    end

    assert_response :ok  # 更新なので ok
    
    json_response = JSON.parse(response.body)
    assert_equal user_crop.id, json_response['crop_id']
    assert_equal false, json_response['is_reference']
    assert_match /更新/, json_response['message']
    
    # 最新データで更新されている
    user_crop.reload
    assert_not_nil user_crop.area_per_unit
    assert user_crop.crop_stages.count > 0
  end
end

