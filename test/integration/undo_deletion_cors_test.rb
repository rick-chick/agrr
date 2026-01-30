# frozen_string_literal: true

require 'test_helper'

# CORS 設定の検証: Angular (localhost:4200) から undo_deletion への
# プリフライト (OPTIONS) および POST で CORS ヘッダーが返ることを確認する。
class UndoDeletionCorsTest < ActionDispatch::IntegrationTest
  include Rails.application.routes.url_helpers

  FRONTEND_ORIGIN = 'http://localhost:4200'

  test 'OPTIONS /ja/undo_deletion returns CORS headers for frontend origin' do
    options "/ja/undo_deletion",
            headers: {
              'Origin' => FRONTEND_ORIGIN,
              'Access-Control-Request-Method' => 'POST',
              'Access-Control-Request-Headers' => 'Content-Type'
            }
    assert_response :success
    assert_equal FRONTEND_ORIGIN, response.headers['Access-Control-Allow-Origin'],
                 'CORS で Access-Control-Allow-Origin が返ること'
    assert_includes response.headers['Access-Control-Allow-Methods'], 'POST',
                    'Access-Control-Allow-Methods に POST が含まれること'
  end

  test 'OPTIONS /undo_deletion (no locale) returns CORS headers for frontend origin' do
    options "/undo_deletion",
            headers: {
              'Origin' => FRONTEND_ORIGIN,
              'Access-Control-Request-Method' => 'POST',
              'Access-Control-Request-Headers' => 'Content-Type'
            }
    assert_response :success
    assert_equal FRONTEND_ORIGIN, response.headers['Access-Control-Allow-Origin'],
                 'CORS で Access-Control-Allow-Origin が返ること'
  end

  test 'POST /ja/undo_deletion response includes CORS headers when Origin is frontend' do
    post "/ja/undo_deletion",
         params: { undo_token: 'non-existent-token-for-cors-check' },
         headers: {
           'Origin' => FRONTEND_ORIGIN,
           'Content-Type' => 'application/json'
         },
         as: :json
    # トークン無効で 422 になるが、CORS ヘッダーは付与されていること
    assert_equal FRONTEND_ORIGIN, response.headers['Access-Control-Allow-Origin'],
                 'POST レスポンスにも CORS ヘッダーが付くこと'
  end
end
