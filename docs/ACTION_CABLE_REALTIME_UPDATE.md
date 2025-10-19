# Action Cable リアルタイム更新実装

## 概要

ドラッグアンドドロップでの自動最適化が完了した後、ページリロードではなくAction Cableを使ったリアルタイム更新を実装しました。

## 実装内容

### 1. JavaScript側

#### `app/javascript/cable_subscription.js`
- Action Cableのサブスクリプション管理クラスを作成
- `OptimizationChannel`への接続・切断・メッセージ受信を管理

#### `app/javascript/custom_gantt_chart.js`
- `setupCableSubscription()`: 初期化時にAction Cableサブスクリプションを設定
- `handleOptimizationUpdate()`: サーバーからのメッセージを処理
- `fetchAndUpdateChart()`: データを再取得してチャートを更新
- `executeReoptimization()`: `location.reload()`を削除し、Action Cableからの通知を待機
- `revertChanges()`: `location.reload()`を削除し、データ再取得に変更

### 2. サーバー側

#### `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`
- **新規アクション: `data`**
  - `GET /api/v1/public_plans/cultivation_plans/:id/data`
  - 栽培計画データをJSON形式で返す
  - JavaScriptからのデータ再取得リクエストに応答

- **`adjust`アクション更新**
  - `broadcast_optimization_complete()`: 最適化完了時にAction Cable経由でブロードキャスト
  - クライアントに`status: 'adjusted'`メッセージを送信

#### `config/routes.rb`
- `GET /api/v1/public_plans/cultivation_plans/:id/data`ルートを追加

## 動作フロー

1. **ユーザーがガントチャートのバーをドラッグ&ドロップ**
   - `custom_gantt_chart.js`の`executeReoptimization()`が実行される
   - ローディングオーバーレイを表示
   - `/api/v1/public_plans/cultivation_plans/:id/adjust`にPOSTリクエスト

2. **サーバー側で最適化処理**
   - `CultivationPlansController#adjust`が実行される
   - 最適化が完了したら`broadcast_optimization_complete()`を呼び出す
   - Action Cable経由で`OptimizationChannel`にブロードキャスト

3. **クライアント側でメッセージ受信**
   - `handleOptimizationUpdate()`がメッセージを受信
   - `status: 'adjusted'`の場合、`fetchAndUpdateChart()`を実行
   - `/api/v1/public_plans/cultivation_plans/:id/data`にGETリクエスト
   - 取得したデータでガントチャートを再描画
   - ローディングオーバーレイを非表示

## テスト手順

### 1. Dockerコンテナを起動

```bash
cd /home/akishige/projects/agrr
npm run build  # JavaScriptをビルド
docker-compose up
```

### 2. ブラウザでアクセス

```
http://localhost:3000
```

### 3. 公開作付け計画を作成

1. トップページから「公開作付け計画」を作成
2. 圃場サイズと作物を選択
3. 最適化を実行
4. 結果ページでガントチャートが表示される

### 4. ドラッグ&ドロップをテスト

1. ガントチャートのバー（栽培スケジュール）をドラッグ
2. 別の圃場または別の日付にドロップ
3. **期待される動作**:
   - ローディングオーバーレイが表示される
   - サーバー側で最適化が実行される
   - **ページリロードなし**でガントチャートが更新される
   - ローディングオーバーレイが非表示になる

### 5. デバッグログの確認

#### ブラウザのコンソールログ

```javascript
📡 Action Cableサブスクリプションを設定中...
✅ 最適化チャンネルに接続しました
🔄 自動再最適化を開始...
✅ 再最適化リクエストが成功しました。Action Cable経由で更新を待機します。
📬 最適化更新を受信: {status: 'adjusted', ...}
🔄 最適化更新を処理中: {status: 'adjusted', ...}
✅ 最適化が完了しました。データを更新します。
🔄 データを再取得中...
📊 データ取得成功: {...}
✅ チャートを更新しました
```

#### サーバーログ（Docker）

```bash
docker-compose logs web --tail=100 | grep -E "Action Cable|Broadcasting"
```

期待されるログ:
```
📡 [Action Cable] Broadcasting optimization complete for plan_id=...
✅ [Action Cable] Broadcast sent successfully
```

## トラブルシューティング

### Action Cable接続エラー

**症状**: `❌ CableSubscriptionManager not loaded`

**原因**: `cable_subscription.js`が読み込まれていない

**解決方法**:
```bash
npm run build
docker-compose restart web
```

### データ更新が行われない

**症状**: ローディングオーバーレイが表示されたまま

**原因**: Action Cableメッセージが受信されていない

**確認方法**:
1. ブラウザのコンソールで`📬 最適化更新を受信`ログがあるか確認
2. サーバーログで`Broadcasting optimization complete`があるか確認

**解決方法**:
- セッションIDの認証を確認（`OptimizationChannel#subscribed`）
- `cable.yml`の設定を確認（Docker環境では`async`アダプター使用）

### フォールバック動作

データ取得エラー時は自動的に`location.reload()`が実行されます。

## 技術仕様

### Action Cable設定

- **開発環境**: `async`アダプター
- **本番環境**: `solid_cable`アダプター（SQLite-based）
- **WebSocketエンドポイント**: `/cable`

### メッセージ形式

#### サーバー → クライアント

```json
{
  "status": "adjusted",
  "message": "最適化が完了しました",
  "total_profit": 1234567,
  "total_revenue": 2345678,
  "total_cost": 1111111,
  "field_cultivations_count": 10
}
```

#### データ取得API

**リクエスト**: `GET /api/v1/public_plans/cultivation_plans/:id/data`

**レスポンス**:
```json
{
  "success": true,
  "cultivations": [
    {
      "id": 1,
      "crop_name": "トマト（桃太郎）",
      "field_name": "圃場1",
      "field_id": 1,
      "start_date": "2025-04-01",
      "completion_date": "2025-06-30",
      "cultivation_days": 90,
      "area": 100.0,
      "estimated_cost": 50000,
      "profit": 80000,
      "revenue": 130000
    }
  ],
  "total_profit": 800000,
  "total_revenue": 1300000,
  "total_cost": 500000
}
```

## 今後の改善案

1. **進捗バーの表示**: `progress`メッセージを受信時に進捗バーを表示
2. **エラーハンドリングの強化**: より詳細なエラーメッセージを表示
3. **楽観的UI更新**: ドラッグ中に仮の位置を表示
4. **アニメーション**: チャート更新時にスムーズなアニメーション

## 関連ファイル

- `app/javascript/cable_subscription.js`
- `app/javascript/custom_gantt_chart.js`
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`
- `app/channels/optimization_channel.rb`
- `config/routes.rb`
- `config/cable.yml`

