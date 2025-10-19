# ドラッグアンドドロップ処理のパフォーマンス調査報告

## 調査日時
2025-10-19

## 調査対象
agrr allocate adjustのドラッグアンドドロップ処理

## 実施した対応

### 1. パフォーマンス測定コードの追加

処理の各段階に時間計測ログを追加しました：

#### フロントエンド（JavaScript）
- **ファイル**: `app/javascript/custom_gantt_chart.js`
- **測定ポイント**:
  - executeReoptimization()の開始
  - fetch()の開始
  - HTTPレスポンスの受信
  - JSONパースの完了
  - 合計処理時間

#### バックエンド Controller
- **ファイル**: `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`
- **測定ポイント**:
  - adjust()メソッドの開始
  - DB読み込み
  - 各種データ構築（割り当て、圃場、作物、ルール）
  - AdjustGateway.adjust()の実行
  - DB保存
  - 合計処理時間と内訳

#### Gateway層
- **ファイル**: `app/gateways/agrr/adjust_gateway.rb`
- **測定ポイント**:
  - 一時ファイル作成
  - Pythonコマンド（`agrr optimize adjust`）の実行
  - 結果のパース
  - 合計処理時間と内訳

### 2. テスト環境の準備

- JavaScriptのビルド完了
- Dockerコンテナ起動確認
- テスト用栽培計画の作成（Plan ID: 22）

## 特定した処理フロー

```
1. [JavaScript] ドラッグ完了 → executeReoptimization()
2. [JavaScript] fetch() でAPI呼び出し
3. [Rails] adjust() メソッド開始
4. [Rails] DB読み込み
5. [Rails] データ構築（割り当て、圃場、作物、ルール）
6. [Gateway] 一時ファイル作成
7. [Gateway] Pythonコマンド実行 ★最も時間がかかる可能性が高い
8. [Gateway] 結果パース
9. [Rails] DB保存
10. [Rails] JSONレスポンス返却
11. [JavaScript] レスポンス受信、JSONパース
12. [JavaScript] location.reload() ★ページ全体をリロード
```

## 想定されるボトルネック

以下の3つが主なボトルネックと想定されます：

### 1. Pythonコマンドの実行（最有力）
**箇所**: Gateway層の`agrr optimize adjust`コマンド

**理由**:
- 最適化アルゴリズムの計算が重い
- GDD（成長度日）計算などの気象データ処理
- 制約条件（休閑期間、圃場の重複チェック等）の検証

**確認方法**: Gateway層のログで`Python実行: XXXms`を確認

**対策案**:
- タイムアウト設定の追加
- キャッシュの活用（気象データ、GDD計算結果）
- アルゴリズムの最適化
- 不要な計算の削減

### 2. ページ全体のリロード
**箇所**: `location.reload()`

**理由**:
- 成功時に必ずページ全体をリロードしている
- 気象データや栽培データの再取得
- DOM要素の完全な再描画

**確認方法**: ブラウザのNetwork タブでリロード後の通信量を確認

**対策案**:
- `location.reload()`の代わりに部分更新
- 楽観的UI更新（先に画面を更新、エラー時のみ戻す）
- WebSocketやServer-Sent Eventsでリアルタイム更新

### 3. データ構築処理
**箇所**: Controller層のbuild_*メソッド群

**理由**:
- N+1クエリの可能性
- JSON変換処理
- 複雑なデータ変換

**確認方法**: Controller層のログで`データ構築: XXXms`を確認

**対策案**:
- Eager Loading（`includes`）の追加
- データ構造の最適化
- 不要なデータの削減

## 次のステップ

### 即時対応（実測が必要）

1. **ブラウザでテスト実行**
   ```
   URL: http://localhost:3000/public_plans/results?plan_id=22
   ```

2. **ブラウザコンソールでログ確認**
   - 開発者ツール（F12）→ Console タブ
   - `[PERF]`でフィルタリング

3. **Railsログ確認**
   ```bash
   docker-compose logs web | grep "PERF"
   ```

4. **結果の分析**
   - 最も時間がかかっている処理を特定
   - DRAG_DROP_PERFORMANCE_ANALYSIS.mdの報告フォーマットで記録

### 短期対応（UI/UX改善）

1. **ローディングインジケーター追加**
   - ドラッグ後に「最適化中...」の表示
   - プログレスバーの追加

2. **楽観的UI更新**
   - バーの移動を即座に反映
   - エラー時のみロールバック

### 中期対応（パフォーマンス最適化）

1. **Pythonコマンドの最適化**
   - プロファイリングツールでボトルネック特定
   - アルゴリズムの改善

2. **ページリロードの削除**
   - 部分更新への変更
   - APIレスポンスでガントチャートを再描画

3. **キャッシュの活用**
   - 気象データのキャッシュ
   - GDD計算結果のキャッシュ

## 関連ドキュメント

- `DRAG_DROP_PERFORMANCE_ANALYSIS.md` - 詳細な調査手順と報告フォーマット

## 変更ファイル一覧

- `app/javascript/custom_gantt_chart.js` - フロントエンドの時間計測追加
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb` - Controllerの時間計測追加
- `app/gateways/agrr/adjust_gateway.rb` - Gatewayの時間計測追加
- `app/assets/builds/application.js` - JavaScriptビルド結果
- `DRAG_DROP_PERFORMANCE_ANALYSIS.md` - 調査手順書（新規作成）
- `PERFORMANCE_INVESTIGATION_REPORT.md` - 本レポート（新規作成）

---

## まとめ

ドラッグアンドドロップ処理の時間がかかる原因を特定するため、処理の各段階に詳細な時間計測ログを追加しました。

**最も可能性が高いボトルネック**:
1. Pythonコマンドの実行（最適化アルゴリズム）
2. ページ全体のリロード（location.reload()）

**次に必要なアクション**:
1. 実際にブラウザでドラッグアンドドロップ操作を行う
2. ブラウザコンソールとRailsログで時間を測定する
3. ボトルネックを特定して対策を実施する

詳細な調査手順は `DRAG_DROP_PERFORMANCE_ANALYSIS.md` を参照してください。

