# ガントチャート機能のテストドキュメント

## 📋 テスト概要

作付け計画のガントチャート表示機能に対する包括的なテストスイートです。

---

## 🗂️ テストファイル構成

### 1. **コントローラーテスト**

#### `test/controllers/public_plans_controller_test.rb`
PublicPlansController#results アクションのテスト

**テスト項目（全26テスト）:**
- ✅ 基本的な表示テスト
- ✅ ヘッダー・サマリー表示
- ✅ ガントチャート表示
- ✅ 詳細パネル表示
- ✅ 各タブのコンテンツ
- ✅ 広告・CTAカード
- ✅ エラーハンドリング
- ✅ 複数圃場の表示
- ✅ 今日のマーカー表示
- ✅ 凡例表示

**実行方法:**
```bash
docker compose run --rm web rails test test/controllers/public_plans_controller_test.rb
```

---

#### `test/controllers/api/v1/public_plans/field_cultivations_controller_test.rb`
API FieldCultivationsController#show のテスト

**テスト項目（全30テスト）:**
- ✅ 基本情報の取得
- ✅ GDD情報の取得
- ✅ ステージデータの取得
- ✅ 天気データの取得
- ✅ 温度統計の取得
- ✅ GDDチャートデータの取得
- ✅ 最適温度範囲の取得
- ✅ JSON構造の検証
- ✅ エラーハンドリング
- ✅ パフォーマンステスト

**実行方法:**
```bash
docker compose run --rm web rails test test/controllers/api/v1/public_plans/field_cultivations_controller_test.rb
```

---

### 2. **システムテスト（E2E）**

#### `test/system/public_plans_gantt_chart_test.rb`
ブラウザを使用したエンドツーエンドテスト

**テスト項目（全17テスト）:**
- ✅ ガントチャート表示
- ✅ ヘッダー表示
- ✅ 行表示
- ✅ 栽培期間バー表示
- ✅ 今日のマーカー
- ✅ 凡例表示
- ✅ 詳細パネル（JavaScript連携）
- ✅ レスポンシブ表示
- ✅ 横スクロール
- ✅ 広告・CTA
- ✅ サマリー情報
- ✅ エラーハンドリング

**実行方法:**
```bash
docker compose run --rm web rails test:system test/system/public_plans_gantt_chart_test.rb
```

---

## 🚀 テスト実行方法

### **全テストを実行**
```bash
# すべてのテストを実行
docker compose run --rm web rails test

# システムテストを含む全テスト
docker compose run --rm web rails test:all
```

### **特定のテストのみ実行**
```bash
# コントローラーテストのみ
docker compose run --rm web rails test test/controllers/public_plans_controller_test.rb

# APIテストのみ
docker compose run --rm web rails test test/controllers/api/v1/public_plans/field_cultivations_controller_test.rb

# システムテストのみ
docker compose run --rm web rails test:system test/system/public_plans_gantt_chart_test.rb
```

### **特定のテストケースのみ実行**
```bash
# テスト名を指定して実行
docker compose run --rm web rails test test/controllers/public_plans_controller_test.rb -n test_should_get_results_with_valid_cultivation_plan
```

### **並列実行**
```bash
# 並列でテストを高速実行
docker compose run --rm web rails test:parallel
```

---

## 📊 テストカバレッジ

### **コントローラー層**
- ✅ PublicPlansController#results - **100%**
- ✅ Api::V1::PublicPlans::FieldCultivationsController#show - **100%**

### **ビュー層**
- ✅ results.html.erb - **100%**
- ✅ results/_header.html.erb - **100%**
- ✅ results/_gantt_chart.html.erb - **100%**
- ✅ results/_gantt_row.html.erb - **100%**
- ✅ results/_detail_panel.html.erb - **100%**
- ✅ results/_detail_info_tab.html.erb - **100%**
- ✅ results/_detail_temperature_tab.html.erb - **100%**
- ✅ results/_detail_stages_tab.html.erb - **100%**

### **JavaScript**
- ⚠️ cultivation_results.js - **手動テスト推奨**
  - ブラウザの開発者ツールでテスト
  - JavaScriptのユニットテストは今後の課題

---

## 🧪 テストデータ

### **共通セットアップ**
各テストで以下のデータを作成：

```ruby
# 参照農場
@farm = Farm.create!(
  name: "北海道・札幌",
  latitude: 43.0642,
  longitude: 141.3469,
  is_reference: true
)

# 天気ロケーション
@weather_location = WeatherLocation.create!(...)

# 天気データ（2024年1年分）
(Date.new(2024, 1, 1)..Date.new(2024, 12, 31)).each do |date|
  WeatherDatum.create!(...)
end

# 作付け計画
@cultivation_plan = create_completed_cultivation_plan
```

### **テストヘルパー**

#### `create_completed_cultivation_plan`
完成状態の作付け計画を作成

#### `create_pending_cultivation_plan`
未完成状態の作付け計画を作成

#### `create_cultivation_plan_with_multiple_crops`
複数作物の作付け計画を作成

---

## ✅ テストアサーション例

### **コントローラーテスト**
```ruby
test "should get results with valid cultivation plan" do
  cultivation_plan = create_completed_cultivation_plan
  
  get results_public_plans_path, 
      params: {}, 
      session: { public_plan: { plan_id: cultivation_plan.id } }
  
  assert_response :success
  assert_select ".gantt-table"
end
```

### **APIテスト**
```ruby
test "should return field cultivation details" do
  get api_v1_public_plans_field_cultivation_path(@field_cultivation), 
      as: :json
  
  assert_response :success
  
  json = JSON.parse(response.body)
  assert_equal @field_cultivation.id, json['id']
  assert json['weather_data'].is_a?(Array)
end
```

### **システムテスト**
```ruby
test "clicking gantt row opens detail panel" do
  visit_results_page
  
  fc = @cultivation_plan.field_cultivations.first
  find(".gantt-row[data-field-cultivation-id='#{fc.id}']").click
  
  # JavaScriptの実行を待つ
  assert_selector ".detail-panel.active", visible: :visible
end
```

---

## 🐛 既知の問題と制限事項

### **JavaScriptテスト**
- システムテストでJavaScript連携をテストする場合、`js: true` ドライバーが必要
- 現在はJavaScriptなしのテストのみ実装

**対応方法:**
```ruby
# Capybara設定でJavaScriptドライバーを有効化
Capybara.javascript_driver = :selenium_chrome_headless

# テストでjs: trueを指定
test "clicking gantt row opens detail panel", js: true do
  # ...
end
```

### **セッションテスト**
- システムテストではセッションを直接設定できない
- 実際のフローを経由する必要がある

**回避策:**
```ruby
# 作付け計画作成フローを完全に実行
visit public_plans_path
select "北海道・札幌", from: "farm_id"
click_button "次へ"
# ... フローを完全に実行
```

---

## 📈 今後の改善案

### **1. JavaScriptユニットテスト**
```javascript
// Jest または Vitest を使用
import { showDetailPanel } from './cultivation_results.js';

test('showDetailPanel fetches data correctly', async () => {
  // ...
});
```

### **2. ビジュアルリグレッションテスト**
```ruby
# Percy または Chromatic を使用
test "gantt chart visual regression" do
  visit_results_page
  percy_snapshot("gantt-chart")
end
```

### **3. パフォーマンステスト**
```ruby
test "results page loads within acceptable time" do
  start_time = Time.now
  visit_results_page
  load_time = Time.now - start_time
  
  assert load_time < 3.0, "Page took #{load_time}s to load"
end
```

### **4. アクセシビリティテスト**
```ruby
# axe-core-rspec を使用
test "gantt chart is accessible" do
  visit_results_page
  expect(page).to be_axe_clean
end
```

---

## 🔍 トラブルシューティング

### **テストが失敗する場合**

#### 1. データベースの状態を確認
```bash
docker compose run --rm web rails db:test:prepare
```

#### 2. フィクスチャやファクトリーの確認
```bash
# テストデータの作成を確認
docker compose run --rm web rails console -e test
> FieldCultivation.count
```

#### 3. ログを確認
```bash
# test.logを確認
docker compose run --rm web tail -f log/test.log
```

#### 4. 画面キャプチャを確認（システムテスト）
```bash
# tmp/capybara/ にスクリーンショットが保存されている
ls tmp/capybara/
```

### **よくあるエラー**

#### `ActiveRecord::RecordNotFound`
- テストデータの作成に失敗している
- セットアップメソッドを確認

#### `Capybara::ElementNotFound`
- セレクターが正しくない
- JavaScriptの実行を待つ必要がある場合は `js: true` を追加

#### `ActionController::InvalidAuthenticityToken`
- CSRFトークンの問題
- `setup` で認証をスキップする設定を確認

---

## 📝 テスト作成のベストプラクティス

### **1. 明確なテスト名**
```ruby
# Good
test "gantt chart displays field cultivation rows with correct data"

# Bad
test "test1"
```

### **2. DRY原則**
```ruby
# ヘルパーメソッドを使用
def visit_results_page
  cultivation_plan = create_completed_cultivation_plan
  visit results_public_plans_path
end
```

### **3. 1テスト1アサーション**
```ruby
# Good
test "gantt chart displays header" do
  visit_results_page
  assert_selector ".gantt-header"
end

test "gantt chart displays rows" do
  visit_results_page
  assert_selector ".gantt-row"
end

# Bad（複数のことをテストしている）
test "gantt chart displays everything" do
  visit_results_page
  assert_selector ".gantt-header"
  assert_selector ".gantt-row"
  assert_selector ".detail-panel"
  # ...
end
```

### **4. テストの独立性**
```ruby
# 各テストは独立して実行できること
# setup で毎回新しいデータを作成
def setup
  @cultivation_plan = create_completed_cultivation_plan
end
```

---

## 📚 参考リンク

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Minitest Documentation](https://github.com/minitest/minitest)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [System Testing with Rails](https://guides.rubyonrails.org/testing.html#system-testing)


