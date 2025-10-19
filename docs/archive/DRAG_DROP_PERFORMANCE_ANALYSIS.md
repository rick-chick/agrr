# ドラッグアンドドロップ処理のパフォーマンス分析

## 概要

allocate adjust機能のドラッグアンドドロップ処理において、想定以上に時間がかかる問題を調査するため、各処理ステップに時間計測ログを追加しました。

## 処理フロー

```
[フロントエンド: JavaScript]
1. ドラッグ完了
2. executeReoptimization() 呼び出し
3. fetch() でAPIリクエスト送信
   ↓
[バックエンド: Rails Controller]
4. adjust() メソッド開始
5. DB読み込み（cultivation_plan取得）
6. データ構築
   - 現在の割り当てデータ構築
   - 圃場設定構築
   - 作物設定構築
   - 交互作用ルール構築
7. AdjustGateway.adjust() 呼び出し
   ↓
[Gateway層]
8. 一時ファイル作成
9. Pythonコマンド実行（agrr optimize adjust）
10. 結果パース
   ↓
[Controller続き]
11. DB保存
12. JSONレスポンス返却
   ↓
[フロントエンド続き]
13. レスポンス受信
14. JSONパース
15. location.reload() ページリロード
```

## 計測ポイント

### フロントエンド（app/javascript/custom_gantt_chart.js）

以下のログが出力されます：

```
⏱️ [PERF] executeReoptimization() 開始時刻: XXXms
⏱️ [PERF] fetch()開始: XXXms経過
⏱️ [PERF] HTTPレスポンス受信: XXXms
⏱️ [PERF] JSONパース完了: XXXms
⏱️ [PERF] 合計処理時間: XXXms
⏱️ [PERF] - データ準備: XXXms
⏱️ [PERF] - API処理: XXXms
⏱️ [PERF] - JSONパース: XXXms
```

### バックエンド Controller（app/controllers/api/v1/public_plans/cultivation_plans_controller.rb）

以下のログが出力されます：

```
⏱️ [PERF] adjust() 開始: [timestamp]
⏱️ [PERF] DB読み込み完了: XXXms
⏱️ [PERF] 割り当てデータ構築: XXXms
⏱️ [PERF] 圃場設定構築: XXXms
⏱️ [PERF] 作物設定構築: XXXms
⏱️ [PERF] 交互作用ルール構築: XXXms
⏱️ [PERF] AdjustGateway.adjust() 呼び出し開始
⏱️ [PERF] AdjustGateway.adjust() 完了: XXXms
⏱️ [PERF] DB保存完了: XXXms
⏱️ [PERF] === 合計処理時間 ===
⏱️ [PERF] 全体: XXXms
⏱️ [PERF] - DB読み込み: XXXms
⏱️ [PERF] - データ構築: XXXms
⏱️ [PERF] - agrr adjust実行: XXXms
⏱️ [PERF] - DB保存: XXXms
```

### Gateway層（app/gateways/agrr/adjust_gateway.rb）

以下のログが出力されます：

```
⏱️ [PERF Gateway] adjust() 開始
⏱️ [PERF Gateway] ファイル作成完了: XXXms
⏱️ [PERF Gateway] Pythonコマンド実行開始
⏱️ [PERF Gateway] コマンド: [実際のコマンド]
⏱️ [PERF Gateway] Pythonコマンド実行完了: XXXms
⏱️ [PERF Gateway] 結果パース完了: XXXms
⏱️ [PERF Gateway] === Gateway合計 ===
⏱️ [PERF Gateway] 全体: XXXms
⏱️ [PERF Gateway] - ファイル作成: XXXms
⏱️ [PERF Gateway] - Python実行: XXXms
⏱️ [PERF Gateway] - 結果パース: XXXms
```

## 調査手順

### 1. Dockerコンテナを起動

```bash
docker-compose up
```

### 2. ブラウザで栽培計画ページを開く

```
http://localhost:3000/public_plans/cultivation_plans/{計画ID}
```

### 3. ガントチャートでバーをドラッグ

栽培バーをドラッグして別の圃場や日付に移動します。

### 4. ブラウザコンソールログを確認

ブラウザの開発者ツール（F12）でConsoleタブを開き、`[PERF]`でフィルタリングして時間を確認します。

### 5. Railsログを確認

```bash
docker-compose logs -f web
```

または

```bash
tail -f log/docker.log
```

`[PERF]`でgrepして時間を確認します：

```bash
docker-compose logs web | grep "PERF"
```

## 想定されるボトルネック

以下の順に確認することを推奨します：

### 1. Pythonコマンド実行時間

**確認方法**: Gateway層の`Python実行`の時間を確認

**問題の兆候**: 1000ms以上かかっている

**原因候補**:
- `agrr optimize adjust`コマンドの最適化アルゴリズムが重い
- GDD計算などの気象データ処理が重い
- データ量が多い（圃場数、栽培数、期間が長い）

**対策案**:
- タイムアウト設定を追加（`--max-time`オプション）
- 並列処理の最適化
- キャッシュの活用
- アルゴリズムの改善

### 2. ページリロード時間

**確認方法**: フロントエンドの合計処理時間とAPI処理時間の差を確認

**問題の兆候**: `location.reload()`の後に数秒かかる

**原因候補**:
- ページ全体の再読み込みが重い
- 気象データの再取得
- 大量のDOM要素の再描画

**対策案**:
- `location.reload()`の代わりに部分的な更新に変更
- 楽観的UI更新（先に画面を更新してからバックエンドで検証）
- キャッシュの活用

### 3. データ構築処理

**確認方法**: Controller層の`データ構築`の合計時間を確認

**問題の兆候**: 500ms以上かかっている

**原因候補**:
- N+1クエリ問題
- 大量のデータ変換処理
- JSON生成が重い

**対策案**:
- `includes`でEager Loadingを追加
- データ構造の最適化
- 不要なデータの削減

### 4. DB保存処理

**確認方法**: Controller層の`DB保存`の時間を確認

**問題の兆候**: 500ms以上かかっている

**原因候補**:
- トランザクション処理が重い
- バリデーションが重い
- インデックスが不足

**対策案**:
- バッチ更新の活用
- バリデーションの最適化
- インデックスの追加

## 結果の報告フォーマット

調査結果は以下の形式で報告してください：

```
【パフォーマンス分析結果】

■ 環境
- ブラウザ: Chrome/Firefox/Safari XXX
- 計画ID: XXX
- 圃場数: XXX
- 栽培数: XXX
- 計画期間: YYYY-MM-DD ~ YYYY-MM-DD

■ 処理時間の内訳

1. フロントエンド合計: XXXms
   - データ準備: XXXms
   - API処理: XXXms
   - JSONパース: XXXms

2. Controller合計: XXXms
   - DB読み込み: XXXms
   - データ構築: XXXms
   - agrr adjust実行: XXXms
   - DB保存: XXXms

3. Gateway合計: XXXms
   - ファイル作成: XXXms
   - Python実行: XXXms ★
   - 結果パース: XXXms

■ ボトルネック特定

最も時間がかかっている処理: [処理名]
所要時間: XXXms
全体の占める割合: XX%

■ 推奨対策

[具体的な対策案]
```

## 次のステップ

1. **即時対応**: 最も時間がかかっている処理を特定し、クイックウィンの対策を実施
2. **短期対応**: UI/UXの改善（楽観的更新、ローディングインジケーター）
3. **中期対応**: アルゴリズムやアーキテクチャの見直し

## 関連ファイル

- `app/javascript/custom_gantt_chart.js` - フロントエンド処理
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb` - Controller
- `app/gateways/agrr/adjust_gateway.rb` - Gateway
- Pythonコマンド: `agrr optimize adjust`（実装箇所未確認）

---

作成日: 2025-10-19
更新日: 2025-10-19

