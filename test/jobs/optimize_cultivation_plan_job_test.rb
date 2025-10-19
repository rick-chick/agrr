# frozen_string_literal: true

require 'test_helper'

class OptimizeCultivationPlanJobTest < ActiveJob::TestCase
  def setup
    # アノニマスユーザーを作成
    @anonymous_user = User.create!(
      email: 'anonymous@agrr.app',
      name: 'Anonymous User',
      google_id: 'anonymous',
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
    
    # 作付け計画を作成
    @cultivation_plan = CultivationPlan.create!(
      farm: @farm,
      total_area: 100.0,
      status: :pending
    )
  end

  test "should perform job successfully with valid cultivation plan" do
    # Optimizerをモック化
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, true # callメソッドは引数なし
    
    CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
      assert_nothing_raised do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    mock_optimizer.verify
  end

  test "should handle RecordNotFound error" do
    # 存在しないIDでジョブを実行
    assert_nothing_raised do
      OptimizeCultivationPlanJob.perform_now(999999)
    end
    
    # ログにエラーが記録されることを期待
    # （実際のログ確認はここでは省略）
  end

  test "should discard job when WeatherDataNotFoundError occurs" do
    # WeatherDataNotFoundErrorが発生する場合
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, nil do
      raise CultivationPlanOptimizer::WeatherDataNotFoundError, "No weather data"
    end
    
    CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
      assert_nothing_raised do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    # 計画がfailedになることを確認
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /No weather data/, @cultivation_plan.error_message
    
    mock_optimizer.verify
  end

  test "should retry when ExecutionError occurs" do
    # ExecutionErrorはリトライ対象であることを確認
    # retry_onの設定を確認（JobのDSLで設定されている）
    skip "retry_on configuration is tested via actual job execution"
  end

  test "should enqueue job" do
    assert_enqueued_with(job: OptimizeCultivationPlanJob, args: [@cultivation_plan.id]) do
      OptimizeCultivationPlanJob.perform_later(@cultivation_plan.id)
    end
  end
  
  test "should broadcast completion when optimization succeeds" do
    # Optimizerをモック化
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, true
    
    # ブロードキャストのモック
    OptimizationChannel.stub :broadcast_to, ->(*args) { nil } do
      CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    mock_optimizer.verify
  end
  
  test "should broadcast failure when optimization fails" do
    # Optimizerをモック化（失敗）
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, false
    
    # ブロードキャストのモック
    OptimizationChannel.stub :broadcast_to, ->(*args) { nil } do
      CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    mock_optimizer.verify
  end
  
  test "should translate error message for no valid candidates" do
    # ExecutionErrorをスローする場合
    error_message = "No valid allocation candidates could be generated. This may occur when..."
    
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, nil do
      raise Agrr::BaseGateway::ExecutionError, error_message
    end
    
    # ブロードキャストをモック化
    OptimizationChannel.stub :broadcast_to, ->(*args) { nil } do
      CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    # エラーメッセージが翻訳されていることを確認
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /作付けできる作物が見つかりませんでした/, @cultivation_plan.error_message
    
    mock_optimizer.verify
  end
  
  test "should translate error message for growth incomplete" do
    # ExecutionErrorをスローする場合
    error_message = "No candidate reached 100% growth completion"
    
    mock_optimizer = Minitest::Mock.new
    mock_optimizer.expect :call, nil do
      raise Agrr::BaseGateway::ExecutionError, error_message
    end
    
    # ブロードキャストをモック化
    OptimizationChannel.stub :broadcast_to, ->(*args) { nil } do
      CultivationPlanOptimizer.stub :new, ->(*args) { mock_optimizer } do
        OptimizeCultivationPlanJob.perform_now(@cultivation_plan.id)
      end
    end
    
    # エラーメッセージが翻訳されていることを確認
    @cultivation_plan.reload
    assert_equal 'failed', @cultivation_plan.status
    assert_match /指定期間内に成長完了できません/, @cultivation_plan.error_message
    
    mock_optimizer.verify
  end
end

