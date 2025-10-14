# frozen_string_literal: true

require "application_system_test_case"

class OptimizationWebsocketErrorTest < ApplicationSystemTestCase
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
    
    # 参照作物を作成
    @crop = Crop.create!(
      name: "テスト作物",
      variety: "テスト品種",
      is_reference: true
    )
  end
  
  test "shows helpful error message when connection is rejected" do
    skip "This test requires manual verification or mocking WebSocket connection"
    
    # このテストは実装の参考として残す
    # 実際のテストにはWebSocket接続のモックが必要
    
    # 期待される動作:
    # 1. WebSocket接続が拒否される
    # 2. 詳細なエラーメッセージが表示される
    # 3. 5秒後に自動リロードされる
  end
  
  test "falls back to polling after 30 seconds timeout" do
    skip "This test requires manual verification or mocking WebSocket timeout"
    
    # 期待される動作:
    # 1. WebSocket接続が30秒以内に確立しない
    # 2. コンソールに警告が表示される
    # 3. ページがリロードされる（ポーリングに戻る）
  end
end

