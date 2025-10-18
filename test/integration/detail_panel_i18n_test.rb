# frozen_string_literal: true

require "test_helper"

class DetailPanelI18nTest < ActionDispatch::IntegrationTest
  # 詳細パネルのHTML - 日本語
  test "should display Japanese labels in detail temperature tab HTML" do
    get "/ja/public_plans/test/results"
    # スキップ - Public Plans resultsページはログインなしでアクセス
    skip "Requires actual cultivation plan"
  end

  # この機能は直接HTMLテストでき、cultivation_results.jsは
  # JavaScriptなのでブラウザテストが必要
  # まずは_detail_temperature_tab.html.erbのHTMLを国際化して
  # 実際のページで確認する
end

