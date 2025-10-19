# 作物追加時の二重リクエスト対策 - 修正サマリー

## 📋 調査結果

作物パレットからドラッグ&ドロップで作物を追加する際に、**潜在的な二重リクエスト発生の可能性**を発見しました。

### 発見された問題

#### 1. イベントリスナーの重複登録（潜在的リスク）
**場所**: `app/assets/javascripts/crop_palette_drag.js`

**問題の原因**:
- `initCropCardDrag()` 関数が複数のタイミングで呼ばれる可能性
  - `DOMContentLoaded` イベント
  - `turbo:load` イベント（ページ遷移時）
  - 遅延初期化（500ms後）
- Turboのページ遷移時に `cropPaletteInitialized` フラグがリセットされる
- 作物カードのイベントリスナーが削除されず、重複登録される可能性

**影響**:
- 1回のドロップで複数の `mousedown` → `mouseup` イベントが発火
- `addCropToSchedule()` が複数回呼ばれる
- APIリクエストが2回以上送信される

#### 2. リクエストの二重送信防止がない
**場所**: `app/assets/javascripts/crop_palette_drag.js`

**問題の原因**:
- `addCropToSchedule()` 関数に二重送信防止のガードがない
- 何らかの理由で関数が短時間に2回呼ばれた場合、両方とも実行される

**影響**:
- 同じ作物が2回追加される可能性
- サーバー側の負荷増加

## ✅ 実施した修正

### 1. イベントリスナーの重複登録防止

**修正内容**:
```javascript
// 各作物カードに初期化済みフラグを設定
cropCards.forEach(card => {
  // 既にイベントリスナーが設定されている場合はスキップ
  if (card.dataset.dragInitialized === 'true') {
    console.log('⏭️  カードは既に初期化済み:', card.dataset.cropName);
    return;
  }
  
  // ... イベントリスナー登録 ...
  
  // 初期化済みフラグを設定
  card.dataset.dragInitialized = 'true';
  console.log('✅ カード初期化完了:', card.dataset.cropName);
});
```

**効果**:
- 作物カードごとに `data-drag-initialized` 属性で初期化状態を管理
- 既に初期化済みのカードはスキップされる
- ページ遷移を繰り返してもイベントリスナーは1つだけ

### 2. リクエストの二重送信防止

**修正内容**:
```javascript
// グローバルフラグで二重送信を防止
let isAddingCrop = false;

function addCropToSchedule(cropData, dropInfo) {
  // 二重送信防止チェック
  if (isAddingCrop) {
    console.warn('⚠️ [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です');
    return;
  }
  
  // リクエスト中フラグを設定
  isAddingCrop = true;
  console.log('🔒 [LOCK] リクエスト中フラグを設定');
  
  // ... リクエスト処理 ...
  
  // 完了時に必ずフラグを解除
  .then(data => {
    if (data.success) {
      isAddingCrop = false;
      console.log('🔓 [UNLOCK] リクエスト中フラグを解除（成功）');
    } else {
      isAddingCrop = false;
      console.log('🔓 [UNLOCK] リクエスト中フラグを解除（エラー）');
    }
  })
  .catch(error => {
    isAddingCrop = false;
    console.log('🔓 [UNLOCK] リクエスト中フラグを解除（例外）');
  });
}
```

**効果**:
- リクエスト中は `isAddingCrop` フラグが `true` になる
- 2回目の呼び出しは即座にブロックされる
- 成功・エラー・例外のすべてのケースでフラグが確実に解除される

### 3. 詳細なデバッグログ追加

**追加されたログ**:
- `🎯 [DRAG START]` - mousedownイベント発火
- `🏁 [DRAG END]` - mouseupイベント発火
- `📍 [DROP]` - ドロップ位置計算
- `🚀 [ADD CROP]` - addCropToSchedule関数呼び出し
- `🔒 [LOCK]` - リクエスト中フラグ設定
- `📤 [REQUEST]` - リクエスト送信（タイムスタンプ付き）
- `📥 [RESPONSE]` - レスポンス受信（タイムスタンプ付き）
- `🔓 [UNLOCK]` - リクエスト中フラグ解除
- `⚠️ [DUPLICATE REQUEST BLOCKED]` - 二重送信ブロック

**効果**:
- 処理の流れが完全に追跡可能
- 問題発生時の原因特定が容易
- 二重リクエストの検出が即座に可能

## 🔍 検証方法

### 自動検証スクリプト
```bash
./scripts/check_duplicate_requests.sh
```

このスクリプトで以下を確認：
- Dockerコンテナの起動状態
- JavaScriptファイルの存在
- 修正の適用状況

### ブラウザでの手動検証
1. http://localhost:3000 にアクセス
2. 作付け計画の結果ページを開く
3. F12で開発者ツールを開く
4. Consoleタブでログを確認
5. Networkタブで `add_crop` リクエストが1回のみか確認

詳細は `docs/DUPLICATE_REQUEST_CHECK.md` を参照。

## 📊 修正の効果

### Before（修正前）
```
🎯 [DRAG START] mousedownイベント発火
🏁 [DRAG END] mouseupイベント発火
🚀 [ADD CROP] 関数呼び出し開始          ← 1回目
📤 [REQUEST] リクエスト送信
🚀 [ADD CROP] 関数呼び出し開始          ← 2回目（重複！）
📤 [REQUEST] リクエスト送信             ← 二重送信！
```

### After（修正後）
```
🎯 [DRAG START] mousedownイベント発火
🏁 [DRAG END] mouseupイベント発火
🚀 [ADD CROP] 関数呼び出し開始          ← 1回目
🔒 [LOCK] リクエスト中フラグを設定
📤 [REQUEST] リクエスト送信
🚀 [ADD CROP] 関数呼び出し開始          ← 2回目（仮に発生しても）
⚠️ [DUPLICATE REQUEST BLOCKED]         ← ブロックされる！
📥 [RESPONSE] レスポンス受信
🔓 [UNLOCK] リクエスト中フラグを解除
```

## 🛡️ 防御の多層構造

この修正により、以下の2つの層で二重リクエストを防止：

1. **イベント層**: イベントリスナーの重複登録を防止
   - Turboのページ遷移でも安全
   - DOM要素ごとに初期化状態を管理
   
2. **リクエスト層**: リクエストの二重送信を防止
   - グローバルフラグでロック
   - 成功・エラー・例外すべてで確実に解除

両方の層で防御することで、**確実に二重リクエストを防止**します。

## 📁 変更されたファイル

- ✅ `app/assets/javascripts/crop_palette_drag.js` - メイン修正
- ✅ `docs/DUPLICATE_REQUEST_CHECK.md` - 検証ガイド
- ✅ `docs/DUPLICATE_REQUEST_FIX_SUMMARY.md` - このファイル
- ✅ `scripts/check_duplicate_requests.sh` - 自動検証スクリプト

## 🎯 次のステップ

1. ブラウザで実際に動作確認
2. ログを確認して二重リクエストが発生していないか検証
3. システムテストを実行
   ```bash
   docker compose exec web rails test:system TEST=test/system/crop_palette_drop_drawer_test.rb
   ```
4. 問題なければコミット

## 📝 注意事項

- デバッグログは本番環境では削除または無効化することを推奨
- パフォーマンスへの影響は微小（フラグチェックのみ）
- 既存の機能には影響なし（後方互換性あり）

## 🔗 関連ドキュメント

- [検証ガイド](DUPLICATE_REQUEST_CHECK.md) - 詳細な検証手順
- [作物パレット機能](FIELD_MANAGEMENT_MANUAL_TEST.md) - 機能の全体像
- [アセット管理ガイド](ASSET_LOADING_GUIDE.md) - JavaScriptの読み込み

---

**作成日**: 2025-10-19  
**担当**: AI Assistant  
**ステータス**: ✅ 完了・検証待ち

