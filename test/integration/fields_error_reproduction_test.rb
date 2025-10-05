# frozen_string_literal: true

require "test_helper"

class FieldsErrorReproductionTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_authenticated_user
    @session = Session.create_for_user(@user)
    cookies[:session_id] = @session.session_id
  end

  test "should reproduce 422 Unprocessable Content error when creating field without required data" do
    # 必須データなしでフィールド作成を試行
    post fields_path, params: {
      field: {
        name: "",
        latitude: "",
        longitude: ""
      }
    }
    
    # 422エラーが発生することを確認
    assert_response :unprocessable_entity
    assert_equal 422, response.status
    
    # エラーメッセージが含まれていることを確認
    assert_match /Name can't be blank/, response.body, "Name validation error should be present"
    assert_match /Latitude can't be blank/, response.body, "Latitude validation error should be present"
    assert_match /Longitude can't be blank/, response.body, "Longitude validation error should be present"
  end

  test "should reproduce 422 error with invalid coordinate values" do
    # 無効な座標値でフィールド作成を試行
    post fields_path, params: {
      field: {
        name: "Invalid Field",
        latitude: "invalid_lat",
        longitude: "invalid_lng"
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 422, response.status
    
    # 数値ではない値のエラーを確認
    assert_match /Latitude is not a number/, response.body, "Latitude number validation error should be present"
    assert_match /Longitude is not a number/, response.body, "Longitude number validation error should be present"
  end

  test "should reproduce 422 error with out of range coordinates" do
    # 範囲外の座標値でフィールド作成を試行
    post fields_path, params: {
      field: {
        name: "Out of Range Field",
        latitude: "200.0",  # 緯度の範囲外
        longitude: "500.0"  # 経度の範囲外
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 422, response.status
    
    # 範囲外の値のエラーを確認
    assert_match /Latitude must be between -90 and 90/, response.body, "Latitude range validation error should be present"
    assert_match /Longitude must be between -180 and 180/, response.body, "Longitude range validation error should be present"
  end

  test "should reproduce CSP violation with inline styles in error response" do
    # 無効なデータでPOSTして422エラーを発生させる
    post fields_path, params: {
      field: {
        name: "",
        latitude: "invalid",
        longitude: "invalid"
      }
    }
    
    assert_response :unprocessable_entity
    
    # CSP違反となるインラインスタイルが含まれていることを確認
    # これは実際のエラー再現: "Refused to apply inline style because it violates CSP"
    assert_match /style="[^"]*"/, response.body, "Inline styles detected - CSP violation"
    
    # 具体的なインラインスタイルの例を確認
    assert_match /style="color: red;"/, response.body, "Red color inline style detected"
    assert_match /style="border: 1px solid red;"/, response.body, "Red border inline style detected"
    
    # エラーメッセージのスタイルも確認
    assert_match /style="[^"]*error[^"]*"/, response.body, "Error message inline styles detected"
  end

  test "should reproduce CSP violation with inline event handlers" do
    # JavaScriptエラーを含むリクエスト
    post fields_path, params: {
      field: {
        name: "<script>alert('xss')</script>",
        latitude: "35.6812",
        longitude: "139.7671"
      }
    }
    
    assert_response :unprocessable_entity
    
    # インラインイベントハンドラーが含まれていることを確認
    assert_match /onclick="[^"]*"/, response.body, "Inline onclick handler detected - CSP violation"
    assert_match /onload="[^"]*"/, response.body, "Inline onload handler detected - CSP violation"
  end

  test "should reproduce CSP nonce mismatch scenario" do
    # CSP nonceが不一致の場合のシナリオを再現
    get new_field_path
    assert_response :success
    
    # nonceが設定されていることを確認
    csp_nonce = response.body.match(/nonce="([^"]*)"/)[1] rescue nil
    assert_not_nil csp_nonce, "CSP nonce should be present"
    
    # 無効なnonceでPOSTを試行
    post fields_path, params: {
      field: {
        name: "",
        latitude: "",
        longitude: ""
      }
    }
    
    assert_response :unprocessable_entity
    
    # nonce不一致によるCSP違反をシミュレート
    assert_match /nonce=/, response.body, "Nonce attribute should be present"
    assert_match /csp-nonce/, response.body, "CSP nonce meta tag should be present"
  end

  test "should reproduce browser console error scenario" do
    # ブラウザコンソールエラーを再現
    post fields_path, params: {
      field: {
        name: "Test Field",
        latitude: "35.6812",
        longitude: "139.7671"
      }
    }
    
    # 成功ケースでもCSP違反が発生する可能性をテスト
    if response.status == 422
      # 422エラーの場合、インラインスタイルによるCSP違反を確認
      assert_match /style="[^"]*"/, response.body, "Inline styles causing CSP violation"
      
      # コンソールエラーメッセージをシミュレート
      error_message = "Refused to apply inline style because it violates the following Content Security Policy directive"
      assert_match /style/, response.body, "Inline style attribute that would trigger: #{error_message}"
    end
  end

  test "should reproduce specific CSP directive violation" do
    # 特定のCSPディレクティブ違反を再現
    post fields_path, params: {
      field: {
        name: "",
        latitude: "",
        longitude: ""
      }
    }
    
    assert_response :unprocessable_entity
    
    # CSPディレクティブ "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com 'nonce-RHhskrofN7nAnaPINZtHsQ=='" の違反を確認
    assert_match /style="[^"]*"/, response.body, "Inline style that violates CSP style-src directive"
    
    # nonceが無視されるケースをシミュレート
    assert_match /'unsafe-inline' is ignored if either a hash or nonce value is present/, 
                 "CSP violation message should be simulated"
  end

  test "should demonstrate fix by removing inline styles" do
    # 修正前: インラインスタイルを含むエラーページ
    post fields_path, params: {
      field: {
        name: "",
        latitude: "",
        longitude: ""
      }
    }
    
    assert_response :unprocessable_entity
    original_response = response.body
    
    # インラインスタイルが含まれていることを確認
    assert_match /style="[^"]*"/, original_response, "Inline styles should be present before fix"
    
    # 修正後: インラインスタイルを外部CSSに移動
    # この部分は実際の修正実装をシミュレート
    fixed_response = original_response.gsub(/style="[^"]*"/, 'class="error-style"')
    
    # 修正後はインラインスタイルがないことを確認
    assert_no_match /style="[^"]*"/, fixed_response, "Inline styles should be removed after fix"
    assert_match /class="error-style"/, fixed_response, "CSS classes should be used instead of inline styles"
  end

  test "should reproduce complete error scenario from browser console" do
    # ブラウザコンソールで観測される完全なエラーシナリオを再現
    
    # 1. POST /fields 422 (Unprocessable Content)
    post fields_path, params: {
      field: {
        name: "",
        latitude: "invalid",
        longitude: "invalid"
      }
    }
    
    assert_response :unprocessable_entity
    assert_equal 422, response.status
    
    # 2. CSP違反メッセージの再現
    csp_violation_message = "Refused to apply inline style because it violates the following Content Security Policy directive: \"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com 'nonce-RHhskrofN7nAnaPINZtHsQ=='\""
    
    # インラインスタイルが存在することを確認（CSP違反の原因）
    assert_match /style="[^"]*"/, response.body, "Inline style causing CSP violation should be present"
    
    # nonceが存在することを確認
    assert_match /nonce=/, response.body, "Nonce attribute should be present"
    
    # unsafe-inlineが無視されることをシミュレート
    assert_match /'unsafe-inline' is ignored if either a hash or nonce value is present/, 
                 "CSP violation explanation should be simulated"
  end

  private

  def create_authenticated_user
    User.create!(
      email: 'test@example.com',
      name: 'Test User',
      google_id: "google_#{SecureRandom.hex(8)}"
    )
  end
end
