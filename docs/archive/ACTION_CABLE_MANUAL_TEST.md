# Action Cable リアルタイム更新 手動E2Eテスト手順書

## 🎯 目的

ドラッグ&ドロップ後の自動最適化が**Action Cable経由でリアルタイム更新**され、**ページリロードされない**ことを確認する。

## 📋 前提条件

```bash
# Dockerコンテナが起動していること
docker-compose up

# ブラウザでアクセス可能
http://localhost:3000
```

## 🧪 E2Eテスト手順

### STEP 1: 栽培計画を作成

1. ブラウザで `http://localhost:3000/ja` にアクセス
2. 「無料で作付け計画を作成」をクリック
3. 農場サイズを選択（例: 小規模）
4. 作物を2つ以上選択（例: トマト、キュウリ）
5. 「最適化を開始」をクリック
6. 最適化完了まで待機（30秒〜1分）
7. 結果ページが表示される

### STEP 2: ブラウザ開発者ツールを開く

1. **F12キー** を押して開発者ツールを開く
2. **Console** タブを選択

### STEP 3: Action Cable接続を確認

コンソールに以下のログが表示されていることを確認：

```javascript
✅ 最適化チャンネルに接続しました
```

または：

```javascript
📡 [Cable] Connecting to: ws://localhost:3000/ja/cable
```

❌ もし接続ログがない場合：
- ページをリロード（F5）
- WebSocketがブロックされていないか確認

### STEP 4: リロード検出フラグを設定

コンソールで以下を実行：

```javascript
window.pageReloaded = false;
window.addEventListener('beforeunload', function() {
  console.error('❌❌❌ ページがリロードされました！');
  window.pageReloaded = true;
});
console.log('✅ リロード検出フラグを設定しました');
```

### STEP 5: ガントチャートのバーをドラッグ&ドロップ

1. ガントチャート上の**任意の栽培バー**を見つける
2. バーを**クリックして掴む**
3. **右方向に100pxほどドラッグ**（約1週間後に移動）
4. **マウスボタンを離す**

### STEP 6: コンソールログを確認

以下のログが**順番に**出力されることを確認：

```javascript
🔄 自動再最適化を開始...
📋 送信データ: {...}
⏱️ [PERF] fetch()開始: ...
📡 HTTP Response: 200 OK
✅ 再最適化リクエストが成功しました。Action Cable経由で更新を待機します。
📡 Action Cableからの更新を待機中...
```

**ローディングオーバーレイ**が表示されます：
- 半透明の黒い背景
- 「最適化処理中...」のメッセージ
- スピナーアニメーション

### STEP 7: Action Cableメッセージ受信を確認

10〜20秒後、以下のログが出力されることを確認：

```javascript
📬 最適化更新を受信: {status: 'adjusted', ...}
🔄 最適化更新を処理中: {...}
✅ 最適化が完了しました。データを更新します。
🔄 データを再取得中...
📊 データ取得成功: {...}
✅ チャートを更新しました
```

**ローディングオーバーレイが消える**

### STEP 8: ページがリロードされていないことを確認

コンソールで以下を実行：

```javascript
window.pageReloaded
```

**期待される結果:**
```javascript
false  // ← ページはリロードされていない
```

❌ もし `true` または `❌❌❌ ページがリロードされました！` が表示された場合：
**テスト失敗 - このissueを報告してください**

### STEP 9: チャートが更新されていることを確認

1. ガントチャートを目視確認
2. ドラッグしたバーの位置が変わっている（または他の調整が行われている）
3. ページ全体が再読み込みされた形跡がない（スクロール位置が維持されている）

## ✅ 成功条件

- [ ] Action Cableに接続されている
- [ ] ドラッグ&ドロップ後にローディングオーバーレイが表示される
- [ ] HTTPレスポンス200が返ってくる
- [ ] Action Cableメッセージ`status: 'adjusted'`が受信される
- [ ] チャートがリアルタイム更新される
- [ ] **`window.pageReloaded === false`**（ページリロードされていない）
- [ ] スクロール位置が維持されている

## 🐛 トラブルシューティング

### ❌ Action Cableに接続できない

**症状:** `✅ 最適化チャンネルに接続しました` が表示されない

**確認方法:**

```javascript
window.CableSubscriptionManager
```

**解決方法:**
1. ページをリロード（Ctrl + Shift + R）
2. キャッシュをクリア
3. Dockerコンテナを再起動: `docker-compose restart web`

### ❌ ドラッグしても何も起きない

**症状:** ローディングオーバーレイが表示されない

**確認方法:**

```javascript
window.ganttState.moves
```

空の配列 `[]` が返ってくる場合、ドラッグが認識されていません。

**解決方法:**
1. バーを**より長くドラッグ**する（最低100px以上）
2. ドラッグ速度を**ゆっくり**にする
3. 別のバーで試す

### ❌ APIエラーが返ってくる

**症状:** `❌ 再最適化に失敗しました` が表示される

**確認方法:**

サーバーログを確認:
```bash
docker-compose logs web --tail=50 | grep -E "ERROR|Failed"
```

**一般的なエラー:**
1. `Time overlap` - 他の栽培と重複（別の日付を試す）
2. `Cannot complete growth` - 計画期間内に成長完了できない（より早い日付を試す）
3. `Python library error` - agrrコマンドのエラー（Dockerコンテナを再起動）

### ❌ Action Cableメッセージが受信されない

**症状:** 30秒待ってもローディングが消えない

**確認方法:**

サーバーログを確認:
```bash
docker-compose logs web --tail=50 | grep "Broadcasting"
```

`Broadcasting optimization complete` が出ていない場合、サーバー側でブロードキャストに失敗しています。

**解決方法:**
1. Dockerコンテナを再起動
2. Action Cableの設定を確認: `config/cable.yml`

## 📊 期待されるコンソールログ全体

```javascript
// ページロード時
📡 [Cable] Connecting to: ws://localhost:3000/ja/cable
✅ 最適化チャンネルに接続しました

// リロード検出フラグ設定後
✅ リロード検出フラグを設定しました

// ドラッグ&ドロップ後
🔄 自動再最適化を開始... (呼び出し回数: 1)
⏱️ [PERF] executeReoptimization() 開始時刻: ...
📋 送信データ: {cultivation_plan_id: 23, moves: Array(1)}
⏱️ [PERF] fetch()開始: ...
⏱️ [PERF] HTTPレスポンス受信: ...
📡 HTTP Response: 200 OK
⏱️ [PERF] JSONパース完了: ...
📊 API Response: {success: true, message: "調整が完了しました", ...}
✅ 再最適化リクエストが成功しました。Action Cable経由で更新を待機します。
⏱️ [PERF] 合計処理時間: ...
📡 Action Cableからの更新を待機中...

// 10-20秒後
📬 最適化更新を受信: {status: 'adjusted', message: '最適化が完了しました', ...}
🔄 最適化更新を処理中: {status: 'adjusted', ...}
✅ 最適化が完了しました。データを更新します。
🔄 データを再取得中...
📊 データ取得成功: {success: true, cultivations: Array(3), ...}
✅ チャートを更新しました
```

## 🎬 動画での確認推奨

可能であれば、以下の動画キャプチャを取得することを推奨：

1. ドラッグ操作
2. ローディング表示
3. チャート更新
4. **ページがリロードされていないこと**（URLバーやスクロール位置が変わらない）

---

## ✅ まとめ

このテストが成功すれば、**Action Cableリアルタイム更新が正常に動作している**ことが証明されます。

**重要な確認ポイント:**
- `window.pageReloaded === false`
- コンソールログに `📬 最適化更新を受信` が表示される
- ローディングオーバーレイが表示され、その後自動的に消える
- ガントチャートが更新される

