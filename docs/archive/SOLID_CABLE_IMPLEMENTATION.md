# Solid Cable WebSocket実装ドキュメント

## 概要

計画作成の進捗確認画面を、ポーリングベースからSolid Cableを使ったWebSocketベースのリアルタイム通信に変更しました。

## 実装内容

### 1. ActionCableチャンネル

#### `app/channels/application_cable/connection.rb`
- セッションIDベースの接続管理（認証不要の公開機能のため）
- 各接続をセッションIDで識別

#### `app/channels/application_cable/channel.rb`
- 基本的なチャンネルクラス

#### `app/channels/optimization_channel.rb`
- 計画最適化の進捗をブロードキャストするチャンネル
- 購読時にcultivation_plan_idで特定の計画にストリームを開始
- 既に完了している場合は即座に完了通知を送信

### 2. バックグラウンドジョブの更新

#### `app/jobs/optimize_cultivation_plan_job.rb`
- 最適化完了時にWebSocketでブロードキャスト
- 成功時: `broadcast_completion`メソッドで完了通知
- 失敗時: `broadcast_failure`メソッドで失敗通知

### 3. フロントエンド実装

#### `app/javascript/optimizing.js`
- **旧実装**: 3秒ごとにページリロード（ポーリング）
- **新実装**: ActionCableでWebSocket接続
  - OptimizationChannelに購読
  - 完了通知を受信したら結果画面へリダイレクト
  - 失敗通知を受信したらアラート表示
  - ページ離脱時にクリーンアップ

#### `app/views/public_plans/optimizing.html.erb`
- `data-cultivation-plan-id`属性を追加してJavaScriptから計画IDを取得可能に

### 4. ルーティング

#### `config/routes.rb`
- ActionCableサーバーを`/cable`にマウント

### 5. 設定ファイル

#### `config/cable.yml`
- 既にSolid Cableが設定済み
- development、docker、productionすべてで`solid_cable`アダプターを使用

## メリット

### 1. リソース効率の向上
- **旧実装**: 3秒ごとにページ全体をリロード
- **新実装**: WebSocketで必要な情報のみ受信

### 2. リアルタイム性の向上
- ジョブ完了と同時に通知が届く
- ポーリング間隔（3秒）の待ち時間がなくなる

### 3. サーバー負荷の軽減
- ページリロードによるHTML生成が不要
- データベースクエリの削減

### 4. ユーザー体験の向上
- スムーズな画面遷移
- ページリロードのちらつきがない

## データフロー

```
1. ユーザーが計画作成
   ↓
2. optimizing画面に遷移
   ↓
3. JavaScript: OptimizationChannelに購読
   ↓
4. バックグラウンド: OptimizeCultivationPlanJob実行
   ↓
5. ジョブ完了: OptimizationChannel.broadcast_to
   ↓
6. JavaScript: メッセージ受信 → results画面へリダイレクト
```

## テスト

### チャンネルテスト
- `test/channels/optimization_channel_test.rb`
  - 購読のテスト
  - 無効な計画IDの拒否
  - 完了済み計画の即時通知

### ジョブテスト
- `test/jobs/optimize_cultivation_plan_job_test.rb`
  - ブロードキャスト成功のテスト
  - ブロードキャスト失敗のテスト

### 統合テスト
- `test/integration/public_plan_creation_test.rb`
  - 計画作成フロー全体のテスト

## 動作確認方法

```bash
# Dockerコンテナを起動
docker compose up -d

# ブラウザで確認
# 1. http://localhost:3000/public_plans にアクセス
# 2. 地域、サイズ、作物を選択
# 3. 計画作成 → 最適化画面
# 4. ブラウザの開発者ツールコンソールを開く
# 5. WebSocket接続と完了通知のログを確認

# テストの実行
docker compose run --rm test bundle exec rails test test/channels/optimization_channel_test.rb
docker compose run --rm test bundle exec rails test test/jobs/optimize_cultivation_plan_job_test.rb
```

## コンソールログ例

```
🔌 Optimizing WebSocket script loading
🔌 Connecting to OptimizationChannel for plan: 123
✅ Connected to OptimizationChannel
📨 Received: {status: 'completed', progress: 100, message: '最適化が完了しました'}
✅ Optimization completed! Redirecting to results...
```

## 今後の拡張可能性

### 1. 進捗の段階的通知
現在は完了時のみ通知していますが、各作物の最適化完了時に通知することで、リアルタイムの進捗表示が可能。

```ruby
# 例: CultivationPlanOptimizerで各作物完了時
OptimizationChannel.broadcast_to(
  cultivation_plan,
  {
    status: 'in_progress',
    progress: cultivation_plan.optimization_progress,
    completed_count: completed,
    total_count: total
  }
)
```

### 2. プログレスバーのアニメーション
フロントエンドで進捗率を受信してバーを動的に更新。

### 3. エラーメッセージの詳細化
失敗時に具体的なエラー内容を表示。

## 注意事項

### 1. Solid Cableの特性
- SQLiteベースのメッセージキュー
- 単一サーバー環境に最適
- スケールアウト時はRedisなどの別アダプターを検討

### 2. ブラウザ互換性
- 現代的なブラウザは全てWebSocketをサポート
- 古いブラウザではActionCableが自動的にロングポーリングにフォールバック

### 3. セキュリティ
- 現在はセッションIDベースの識別
- 将来的に認証が必要になった場合は`ApplicationCable::Connection`を拡張

## 関連ファイル

- `app/channels/application_cable/connection.rb`
- `app/channels/application_cable/channel.rb`
- `app/channels/optimization_channel.rb`
- `app/jobs/optimize_cultivation_plan_job.rb`
- `app/javascript/optimizing.js`
- `app/views/public_plans/optimizing.html.erb`
- `config/routes.rb`
- `config/cable.yml`
- `test/channels/optimization_channel_test.rb`
- `test/jobs/optimize_cultivation_plan_job_test.rb`

