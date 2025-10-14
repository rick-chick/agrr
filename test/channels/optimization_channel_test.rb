# frozen_string_literal: true

require "test_helper"

class OptimizationChannelTest < ActionCable::Channel::TestCase
  def setup
    # アノニマスユーザーを作成
    @anonymous_user = User.create!(
      email: 'test@agrr.app',
      name: 'Test User',
      google_id: 'test123',
      is_anonymous: true
    )
    
    # 参照農場を作成
    @farm = Farm.create!(
      user: @anonymous_user,
      name: "テスト農場",
      latitude: 35.6812,
      longitude: 139.7671,
      is_reference: true
    )
    
    # 作物を作成
    @crop = Crop.create!(
      name: "テスト作物",
      variety: "テスト品種",
      is_reference: true
    )
    
    # 計画を作成
    @test_session_id = "test_session_123"
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      user: @anonymous_user,
      session_id: @test_session_id,
      total_area: 30.0,
      status: 'pending'
    )
    
    # Connection stubをセットアップ
    stub_connection(session_id: @test_session_id)
  end
  
  test "subscribes to optimization channel" do
    subscribe(cultivation_plan_id: @cultivation_plan.id)
    
    assert subscription.confirmed?
    assert_has_stream_for @cultivation_plan
  end
  
  test "rejects subscription without valid cultivation plan" do
    subscribe(cultivation_plan_id: 999999)
    
    assert subscription.rejected?
  end
  
  test "transmits completed status for already completed plan" do
    @cultivation_plan.update!(status: 'completed')
    
    subscribe(cultivation_plan_id: @cultivation_plan.id)
    
    assert_equal 1, transmissions.size
    assert_equal 'completed', transmissions.last['status']
    assert_equal 100, transmissions.last['progress']
  end
  
  test "receives broadcast when optimization completes" do
    subscribe(cultivation_plan_id: @cultivation_plan.id)
    
    # ブロードキャストをシミュレート
    perform :received, {
      status: 'completed',
      progress: 100,
      message: '最適化が完了しました'
    }
  end
end


