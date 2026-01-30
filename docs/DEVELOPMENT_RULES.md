# 開発ルール

## アセット管理の厳格なルール

### jsbundling-rails (esbuild)
- **用途**: npmライブラリ（Leaflet、Turbo、Stimulusなど）のバンドルのみ
- **場所**: `app/javascript/` 配下
- **出力**: `app/assets/builds/` にバンドル済みファイル
- **読み込み**: `<%= javascript_include_tag "application", type: "module" %>`

### Propshaft
- **用途**: ローカルの静的アセット（バンドルしない）
- **JavaScript**: `app/assets/javascripts/` 配下
- **CSS**: `app/assets/stylesheets/` 配下  
- **画像**: `app/assets/images/` 配下
- **読み込み**: 
  - JS: `<%= javascript_include_tag "ファイル名", defer: true %>`
  - CSS: `<%= stylesheet_link_tag "ファイル名" %>`
- **特徴**: フィンガープリント付きで配信、サブディレクトリ構造を維持

## 判断基準

### app/javascript/ に置くもの
- npmパッケージを使うコード
- 複数ファイルをバンドルする必要があるコード
- トランスパイルが必要なコード

### app/assets/javascripts/ に置くもの（Propshaft）
- **プロジェクト固有のカスタムスクリプト**
- npmライブラリに依存しないスタンドアロンのJavaScript
- 大きなファイル（バンドルに含めると重くなる）
- **例**: custom_gantt_chart.js, climate_chart.js など

## よくある間違い（絶対にやるな）

❌ `app/javascript/`にカスタムチャートコードを置いてバンドルに含める
❌ Propshaftでnpmライブラリを配信しようとする
❌ `app/assets/builds/`を直接編集する（esbuildの出力先なので上書きされる）

## 新しいJavaScriptファイルを追加するときの判断フロー

1. npmライブラリを使う？
   - YES → `app/javascript/`に置いて`application.js`でimport
   - NO → 次へ

2. 他のJSファイルとバンドルする必要がある？
   - YES → `app/javascript/`に置いて`application.js`でimport
   - NO → 次へ

3. → `app/assets/javascripts/`に置いてPropshaftで配信
   - レイアウトファイルで`<%= javascript_include_tag "ファイル名" %>`で読み込む

## Rails 8の特徴
- モデルに情報が少ない
- 常にwebで最新仕様を検索すること
- dockerでテストすること。ただしdockerc-compose.ymlにテスト機能を追加してとは頼んではいない。

## テスト

⚠️ **重要**: テスト作成時は必ず [docs/TESTING_GUIDELINES.md](docs/TESTING_GUIDELINES.md) を参照してください。

### テスト要件（必須）
- ✅ **モデルレベルのバリデーションテスト**（必須）- 直接データベース操作での制限テスト
- ✅ **サービスオブジェクトの統合テスト**（必須）- サービス経由での制限テスト
- ✅ **リソース制限テスト**（必須）- リソース上限のテスト
- ✅ **パッチは使わない** - Clean Architectureなので依存性注入を使用
- ✅ **モックはconftestに書く** - テストファイルではなくconftestで管理
- ✅ **テストファースト** - 実装前にテストを書く
- ✅ **異常系はエラーを上げる** - フォールバックではなくエラー処理

### テスト実行
```bash
# 全テスト実行
docker compose run --rm test bundle exec rails test

# 特定のテストファイル
docker compose run --rm test bundle exec rails test test/models/farm_test.rb

# 特定のテストメソッド
docker compose run --rm test bundle exec rails test test/models/farm_test.rb -n test_should_prevent_creating_5th_farm
```

詳細: [docs/TESTING_GUIDELINES.md](docs/TESTING_GUIDELINES.md)

## タスク開始前の必須手順

### 呼び出し階層確認と影響調査

各タスクを始める前に、必ず以下の手順を実行すること：

#### 1. 呼び出し元の特定
- どのコンポーネントから呼び出されているかを確認
- パラメータの受け渡し方法を把握
- 呼び出し条件とタイミングを理解

#### 2. データフローの追跡
- 入力パラメータの流れを追跡
- 戻り値や副作用の影響範囲を特定
- 状態変更の波及効果を分析

#### 3. 依存関係の調査
- 他のコンポーネントへの影響範囲を特定
- 直接的な依存関係と間接的な依存関係を区別
- 循環依存の有無を確認

#### 4. 責任範囲の明確化
- 各コンポーネントの責務と境界を理解
- 単一責任の原則に従っているかを確認
- 責任の重複や曖昧さがないかを検証

#### 5. 変更影響の評価
- 修正による波及効果を事前に分析
- 破壊的変更の可能性を評価
- 後方互換性への影響を考慮

## 実装例

### ❌ 悪い例（責任範囲が曖昧）
```ruby
# FetchWeatherDataJobが次のジョブのことを知っている
if farm.weather_data_status == 'completed'
  cultivation_plan.phase_optimizing!(channel_class)  # 次のジョブの責任
end
```

### ✅ 良い例（責任範囲が明確）
```ruby
# FetchWeatherDataJobは自分の仕事のみに集中
if farm.weather_data_status == 'completed'
  Rails.logger.info "Weather data completed, next job will handle phase transition"
end
```

## Frontend（Angular）のリロード防止

- **テンプレートにバインドする値で「毎回新しいオブジェクト／配列」を返す getter は使わない。**  
  子コンポーネントやディレクティブが参照比較で再初期化され、画面が延々とリロードして見える原因になる。
- オプションやレイヤーなどは **プロパティで持ち、`ngOnChanges` や入力変更時だけ更新する**。

詳細: [docs/analysis/reload-problem-and-fixes.md](analysis/reload-problem-and-fixes.md)

## チェックリスト

- [ ] 呼び出し元を特定した
- [ ] データフローを追跡した
- [ ] 依存関係を調査した
- [ ] 責任範囲を明確化した
- [ ] 変更影響を評価した
- [ ] 単一責任の原則に従っている
- [ ] 他のコンポーネントの責務を侵していない
