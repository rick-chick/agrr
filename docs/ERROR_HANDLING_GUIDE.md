# WebSocket エラーハンドリングガイド

## 概要

Solid Cable WebSocket実装におけるエラーハンドリングの詳細とトラブルシューティング方法をまとめたドキュメントです。

---

## エラーケースと対応

### 1. 接続拒否（rejected）

**発生タイミング:**
- セッションIDが一致しない（認可エラー）
- 計画IDが存在しない
- サーバー側で接続を拒否

**ユーザーへの表示:**
```
最適化状況の取得に失敗しました。

以下のいずれかをお試しください：
• ページをリロード（F5キー）
• ブラウザのキャッシュをクリア
• しばらく時間をおいてから再度アクセス

問題が解決しない場合は、新しい計画を作成してください。
```

**自動リカバリ:**
- アラート表示後5秒で自動リロード
- ユーザーがアラートを閉じずに放置しても自動回復

**サーバーログ:**
```
🚫 OptimizationChannel: Unauthorized access attempt for plan_id=123
🚫 OptimizationChannel: Plan not found: plan_id=456
```

**デバッグ方法:**
1. ブラウザのコンソールで`cultivation_plan_id`を確認
2. サーバーログで拒否理由を確認
3. セッションIDが正しいか確認

---

### 2. 接続切断（disconnected）

**発生タイミング:**
- ネットワーク接続が不安定
- サーバーの再起動
- タイムアウト

**自動リカバリ:**
- 30秒のフォールバックタイマーを設定
- 30秒以内に再接続できない場合、ページをリロード（ポーリングに戻る）

**コンソールログ:**
```
❌ Disconnected from OptimizationChannel
⚠️ WebSocket timeout, falling back to polling
🔄 Auto-reloading page...
```

**対処法:**
- 通常はActionCableが自動で再接続を試みる
- 30秒後にフォールバックが発動
- ユーザー側の操作は不要

---

### 3. 接続タイムアウト

**発生タイミング:**
- サーバー応答が遅い
- ファイアウォールがWebSocketをブロック
- プロキシ経由の接続

**自動リカバリ:**
- 30秒のフォールバックタイマー
- タイムアウト後にページリロード
- ポーリング方式に自動的に戻る

**確認方法:**
```javascript
// ブラウザコンソールで確認
console.log('WebSocket URL:', ActionCable.createConsumer().url);
// 期待値: ws://localhost:3000/cable
```

---

### 4. ブロードキャスト失敗

**発生タイミング:**
- Solid Cableのメッセージキューエラー
- データベース接続エラー
- メモリ不足

**サーバーログ:**
```ruby
❌ Broadcast completion failed for plan #123: Connection refused
❌ Broadcast failure failed for plan #456: Timeout error
```

**影響:**
- ジョブ自体は成功
- WebSocket通知のみ失敗
- ユーザーは30秒後のフォールバックで気づく

**対処法:**
1. サーバーログでエラー原因を確認
2. Solid Cableのステータスを確認
3. 必要に応じてサーバーを再起動

---

## トラブルシューティング

### ケース1: 「接続に失敗しました」が頻繁に表示される

**原因:**
- セッションIDの不一致
- 計画が削除されている
- 認可チェックの問題

**確認手順:**
```bash
# 1. サーバーログを確認
docker compose logs web | grep "OptimizationChannel"

# 2. 計画が存在するか確認
docker compose exec web rails runner "puts CultivationPlan.find(123).inspect"

# 3. セッションストアを確認
docker compose exec web rails runner "puts ActionDispatch::Session::CookieStore"
```

**解決策:**
- ブラウザのキャッシュをクリア
- 新しい計画を作成
- セッション設定を確認

---

### ケース2: WebSocketが全く接続しない

**原因:**
- ActionCableの設定エラー
- ルーティングの問題
- ファイアウォール/プロキシ

**確認手順:**
```bash
# 1. ActionCableがマウントされているか確認
docker compose exec web rails routes | grep cable
# 期待値: /cable

# 2. WebSocketが有効か確認
curl -i -N -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: test" \
     http://localhost:3000/cable
# 期待値: 101 Switching Protocols

# 3. 設定を確認
docker compose exec web rails runner "puts Rails.application.config.action_cable.inspect"
```

**解決策:**
```ruby
# config/environments/development.rb
config.action_cable.url = "ws://localhost:3000/cable"
config.action_cable.mount_path = "/cable"
config.action_cable.allowed_request_origins = [
  /http:\/\/localhost:\d+/
]
```

---

### ケース3: 接続はするが完了通知が届かない

**原因:**
- ジョブが失敗している
- ブロードキャストが失敗している
- チャンネル名の不一致

**確認手順:**
```bash
# 1. ジョブのステータスを確認
docker compose exec web rails runner "
  plan = CultivationPlan.find(123)
  puts 'Status: ' + plan.status
  puts 'Progress: ' + plan.optimization_progress.to_s
"

# 2. ジョブログを確認
docker compose logs web | grep "OptimizeCultivationPlanJob"

# 3. ブロードキャストログを確認
docker compose logs web | grep "Broadcast"
```

**解決策:**
- ジョブを手動で再実行
- サーバーを再起動
- ログで詳細なエラーを確認

---

## エラーメッセージ一覧

### ユーザー向けメッセージ

| メッセージ | 原因 | 自動リカバリ |
|-----------|------|------------|
| 最適化状況の取得に失敗しました | 接続拒否 | 5秒後リロード |
| 最適化に失敗しました | ジョブ失敗 | なし |
| （無言のリロード） | タイムアウト | 30秒後リロード |

### サーバーログメッセージ

| ログ | レベル | 意味 |
|------|--------|------|
| 🔌 OptimizationChannel subscribed | INFO | 接続成功 |
| 🚫 Unauthorized access attempt | WARN | 認可エラー |
| 🚫 Plan not found | WARN | 計画が存在しない |
| ❌ Broadcast completion failed | ERROR | ブロードキャスト失敗 |

### ブラウザコンソールログ

| ログ | 意味 |
|------|------|
| 🔌 Optimizing WebSocket script loading | スクリプト読み込み |
| 🔌 Connecting to OptimizationChannel | 接続試行 |
| ✅ Connected to OptimizationChannel | 接続成功 |
| ❌ Disconnected from OptimizationChannel | 切断 |
| ❌ Connection rejected | 接続拒否 |
| ⚠️ WebSocket timeout, falling back to polling | タイムアウト |
| 📨 Received: {...} | メッセージ受信 |
| ✅ Optimization completed! | 完了通知 |

---

## パフォーマンス監視

### 推奨メトリクス

1. **接続成功率**
   ```ruby
   # Solid Cable messages テーブルで確認
   SELECT COUNT(*) FROM solid_cable_messages 
   WHERE channel LIKE '%OptimizationChannel%'
   ```

2. **平均接続時間**
   - ブラウザの開発者ツール > Network > WS

3. **フォールバック発生率**
   - サーバーログで"falling back to polling"をカウント

4. **ブロードキャスト失敗率**
   - サーバーログで"Broadcast * failed"をカウント

---

## ベストプラクティス

### 開発時

1. **ブラウザコンソールを常に開く**
   - F12 > Console
   - WebSocketの接続状態を確認

2. **サーバーログを監視**
   ```bash
   docker compose logs -f web | grep -E "(OptimizationChannel|Broadcast)"
   ```

3. **ネットワークタブでWebSocket確認**
   - F12 > Network > WS
   - メッセージの内容を確認

### 本番環境

1. **モニタリング設定**
   - WebSocket接続数
   - エラー率
   - 平均接続時間

2. **アラート設定**
   - 接続拒否率が10%を超えたら通知
   - ブロードキャスト失敗率が5%を超えたら通知

3. **定期的なログレビュー**
   - 週次でエラーログを確認
   - パターンを分析

---

## 関連ドキュメント

- [SOLID_CABLE_IMPLEMENTATION.md](./SOLID_CABLE_IMPLEMENTATION.md) - 実装詳細
- [ARCHITECTURE_REVIEW_SOLID_CABLE.md](../ARCHITECTURE_REVIEW_SOLID_CABLE.md) - アーキテクチャレビュー
- [SOLID_CABLE_IMPROVEMENTS_APPLIED.md](./SOLID_CABLE_IMPROVEMENTS_APPLIED.md) - 改善履歴

---

**作成日:** 2025-10-13  
**最終更新:** 2025-10-13  
**バージョン:** 1.0

