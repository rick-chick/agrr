# 作物追加時の二重リクエスト検証ガイド

## 概要
作物パレットから作物をドラッグ&ドロップで追加する際に、リクエストが2回送信される問題がないか検証するためのガイドです。

## 実装した対策

### 1. イベントリスナーの重複登録防止
**問題**: ページ遷移（Turbo）の度に `initCropCardDrag()` が呼ばれ、イベントリスナーが重複登録される可能性

**対策**:
```javascript
// 各作物カードに初期化済みフラグを設定
if (card.dataset.dragInitialized === 'true') {
  console.log('⏭️  カードは既に初期化済み:', card.dataset.cropName);
  return;
}
// ... イベントリスナー登録 ...
card.dataset.dragInitialized = 'true';
```

**場所**: `app/assets/javascripts/crop_palette_drag.js:200-338`

### 2. リクエストの二重送信防止
**問題**: 何らかの理由で `addCropToSchedule()` が短時間に2回呼ばれる可能性

**対策**:
```javascript
// グローバルフラグで二重送信を防止
let isAddingCrop = false;

function addCropToSchedule(cropData, dropInfo) {
  if (isAddingCrop) {
    console.warn('⚠️ [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です');
    return;
  }
  isAddingCrop = true;
  // ... リクエスト処理 ...
  // 完了時に必ずフラグを解除
  isAddingCrop = false;
}
```

**場所**: `app/assets/javascripts/crop_palette_drag.js:409-502`

### 3. 詳細なデバッグログ
以下のログを追加して、リクエストのフローを追跡可能にしました：

- `🎯 [DRAG START]` - mousedownイベント発火
- `🏁 [DRAG END]` - mouseupイベント発火  
- `📍 [DROP]` - ドロップ位置計算
- `🚀 [ADD CROP]` - addCropToSchedule関数呼び出し
- `🔒 [LOCK]` - リクエスト中フラグ設定
- `📤 [REQUEST]` - リクエスト送信（タイムスタンプ付き）
- `📥 [RESPONSE]` - レスポンス受信（タイムスタンプ付き）
- `🔓 [UNLOCK]` - リクエスト中フラグ解除
- `⚠️ [DUPLICATE REQUEST BLOCKED]` - 二重送信がブロックされた場合

## 検証手順

### 1. Dockerコンテナで動作確認

```bash
# コンテナを起動
docker compose up -d

# Railsコンソールでログを確認
docker compose logs -f web
```

### 2. ブラウザで動作確認

1. ブラウザで http://localhost:3000 にアクセス
2. 作付け計画の結果ページを開く
3. **開発者ツールを開く** (F12)
4. **Consoleタブ**を開く
5. **Networkタブ**も開く（Fetch/XHRでフィルター）

### 3. 作物をドラッグ&ドロップ

1. 作物パレットから作物カードを選択
2. ガントチャート上にドラッグ&ドロップ
3. **Consoleタブ**で以下を確認：
   ```
   🎯 [DRAG START] mousedownイベント発火: トマト
   🏁 [DRAG END] mouseupイベント発火
   📍 [DROP] ドロップ位置計算: {x: 123, y: 456}
   🚀 [ADD CROP] 関数呼び出し開始
   🔒 [LOCK] リクエスト中フラグを設定
   📤 [REQUEST] 作物追加リクエスト送信: 2025-01-01T12:00:00.000Z
   📥 [RESPONSE] レスポンス受信: 2025-01-01T12:00:01.234Z
   🔓 [UNLOCK] リクエスト中フラグを解除（成功）
   ```

4. **Networkタブ**で以下を確認：
   - `/api/v1/public_plans/cultivation_plans/:id/add_crop` へのリクエストが**1回のみ**
   - リクエストのタイムスタンプ（ブラウザのNetworkタブで確認）

### 4. 二重リクエストの検出方法

#### ケース1: イベントリスナーの重複登録
**症状**: 1回のドロップで複数の`mouseup`イベントが発火
**確認方法**:
```
🏁 [DRAG END] mouseupイベント発火  <-- 1回目
🏁 [DRAG END] mouseupイベント発火  <-- 2回目（異常）
```

#### ケース2: リクエストの二重送信
**症状**: `addCropToSchedule`が2回呼ばれる
**確認方法（修正前）**:
```
🚀 [ADD CROP] 関数呼び出し開始
📤 [REQUEST] 作物追加リクエスト送信: 2025-01-01T12:00:00.000Z
🚀 [ADD CROP] 関数呼び出し開始  <-- 2回目（異常）
📤 [REQUEST] 作物追加リクエスト送信: 2025-01-01T12:00:00.001Z
```

**確認方法（修正後）**:
```
🚀 [ADD CROP] 関数呼び出し開始
🔒 [LOCK] リクエスト中フラグを設定
📤 [REQUEST] 作物追加リクエスト送信: 2025-01-01T12:00:00.000Z
🚀 [ADD CROP] 関数呼び出し開始  <-- 2回目
⚠️ [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です  <-- ブロックされた
```

### 5. Networkタブでの確認

1. **Filter**: `add_crop`で検索
2. **リクエスト数**: 1回のドロップにつき1リクエストのみ
3. **タイムスタンプ**: 同じタイムスタンプのリクエストが複数ないか確認

### 6. テストの自動化（推奨）

```bash
# システムテストを実行
docker compose exec web rails test:system TEST=test/system/crop_palette_drop_drawer_test.rb

# 特定のテストのみ実行
docker compose exec web rails test test/system/crop_palette_drop_drawer_test.rb:203
```

## 予想される結果

### 正常な場合
- Consoleログが順番に表示される
- `📤 [REQUEST]`のタイムスタンプが1つだけ
- Networkタブで`add_crop`へのリクエストが1回のみ
- `⚠️ [DUPLICATE REQUEST BLOCKED]`が表示されない

### 二重リクエストが発生している場合（修正前）
- `📤 [REQUEST]`が複数回表示される
- タイムスタンプがミリ秒単位で異なる
- Networkタブで同じリクエストが2回以上

### 二重リクエストがブロックされた場合（修正後）
- `⚠️ [DUPLICATE REQUEST BLOCKED]`が表示される
- `📤 [REQUEST]`は1回のみ
- Networkタブでリクエストは1回のみ

## トラブルシューティング

### ログが表示されない
- ブラウザのコンソールを開いているか確認
- JavaScriptファイルが正しく読み込まれているか確認
  ```javascript
  // ブラウザのコンソールで確認
  typeof window.initCropPalette
  // => "function" が表示されればOK
  ```

### 二重リクエストが検出された場合
1. Consoleログを全てコピー
2. Networkタブのリクエスト詳細をスクリーンショット
3. どのタイミングで発生したか記録
4. 開発チームに報告

## まとめ

この修正により、以下の2つの層で二重リクエストを防止：

1. **イベントリスナー層**: 初期化済みフラグで重複登録を防止
2. **リクエスト層**: グローバルフラグで二重送信を防止

両方の対策を組み合わせることで、確実に二重リクエストを防ぎます。

## 関連ファイル
- `app/assets/javascripts/crop_palette_drag.js` - 作物パレットのドラッグ&ドロップ処理
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb` - APIコントローラー
- `test/system/crop_palette_drop_drawer_test.rb` - システムテスト

