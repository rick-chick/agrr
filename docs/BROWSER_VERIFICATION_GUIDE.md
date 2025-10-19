# ブラウザでの配信確認ガイド

## ✅ サーバー側の確認結果

### 1. ファイルの存在確認
```bash
✅ app/assets/javascripts/crop_palette_drag.js (22KB)
```

### 2. Propshaftの配信パス
```
✅ /assets/crop_palette_drag-85a4f3f4.js
```
※ハッシュ値 `85a4f3f4` はファイル内容に基づいて自動生成されます

### 3. 配信内容の確認
```bash
✅ DUPLICATE REQUEST BLOCKED - 含まれています
✅ dataset.dragInitialized - 含まれています
```

**結論**: サーバー側では正しく配信されています！

---

## 🌐 ブラウザでの確認手順

### Step 1: ブラウザで開く
1. ブラウザで http://localhost:3000 にアクセス
2. 作付け計画の結果ページを開く

### Step 2: 開発者ツールを開く
1. **F12** キーを押して開発者ツールを開く
2. または、右クリック → **検証** を選択

### Step 3: Consoleタブで確認
1. **Console** タブを選択
2. 以下のログが表示されるか確認：
   ```
   🚀 作物パレットJavaScript読み込み完了
   🔍 toggleCropPalette関数: function
   🔍 initCropPalette関数: function
   ```

### Step 4: Sourcesタブで配信ファイルを確認
1. **Sources** タブを選択
2. 左側のツリーで **localhost:3000** → **assets** を展開
3. `crop_palette_drag-85a4f3f4.js` を見つける
4. ファイルを開いて以下を検索：
   - `DUPLICATE REQUEST BLOCKED` ✅
   - `dataset.dragInitialized` ✅
   - `isAddingCrop` ✅

### Step 5: Networkタブでファイル読み込みを確認
1. **Network** タブを選択
2. ページをリロード（Ctrl+R または F5）
3. フィルターで `crop_palette` と検索
4. `crop_palette_drag-85a4f3f4.js` が **200 OK** で読み込まれているか確認

### Step 6: 実際にドラッグ&ドロップして動作確認
1. 作物パレットを開く
2. **Console** タブを開いておく
3. 作物カードをドラッグ&ドロップ
4. 以下のログが表示されるか確認：

#### 正常な動作（期待されるログ）
```
🎯 [DRAG START] mousedownイベント発火: トマト
🏁 [DRAG END] mouseupイベント発火
🏁 [DRAG END] イベントタイムスタンプ: 2025-10-19T23:15:30.123Z
📍 [DROP] ドロップ位置計算: {x: 456.7, y: 123.4}
📍 [DROP] 計算結果: {field_id: "field_1", ...}
✅ [DROP] ドロップ位置が有効 - addCropToSchedule呼び出し
🚀 [ADD CROP] 関数呼び出し開始
🔒 [LOCK] リクエスト中フラグを設定
📤 [REQUEST] 作物追加リクエスト送信: 2025-10-19T23:15:30.234Z
📥 [RESPONSE] レスポンス受信: 2025-10-19T23:15:31.456Z
📥 [RESPONSE] ステータス: 200
📥 [RESPONSE] データ: {success: true, ...}
✅ [SUCCESS] 作物追加成功
🔓 [UNLOCK] リクエスト中フラグを解除（成功）
```

#### 二重リクエストがブロックされた場合
```
🚀 [ADD CROP] 関数呼び出し開始
🔒 [LOCK] リクエスト中フラグを設定
📤 [REQUEST] 作物追加リクエスト送信
🚀 [ADD CROP] 関数呼び出し開始  ← 2回目
⚠️ [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です  ← ブロック！
```

### Step 7: Networkタブでリクエスト数を確認
1. **Network** タブで **Fetch/XHR** でフィルター
2. `add_crop` で検索
3. **1回のドロップにつき1リクエストのみ**か確認
4. リクエストのタイムスタンプが1つだけか確認

---

## 🔍 トラブルシューティング

### ケース1: JavaScriptファイルが読み込まれない
**症状**: Networkタブに `crop_palette_drag.js` が表示されない

**解決方法**:
```bash
# Railsサーバーを再起動
docker compose restart web

# キャッシュをクリア
docker compose exec web rails tmp:cache:clear
```

### ケース2: 古いファイルがキャッシュされている
**症状**: 修正内容が反映されていない

**解決方法**:
1. ブラウザで **Ctrl+Shift+R** (スーパーリロード)
2. または開発者ツールで **Network** タブ → **Disable cache** にチェック

### ケース3: ハッシュ値が異なる
**症状**: `/assets/crop_palette_drag-XXXXXXXX.js` のハッシュ値が異なる

**これは正常です**: ファイル内容が変更されるとハッシュ値も変わります。
Propshaftが自動的に正しいファイルを配信します。

### ケース4: ログが表示されない
**症状**: Consoleタブに何もログが表示されない

**確認事項**:
1. Consoleタブのフィルターが **All levels** になっているか
2. `console.log` が無効化されていないか（ブラウザの設定）
3. JavaScriptエラーが発生していないか（赤いエラーメッセージを確認）

---

## 📊 期待される結果

### ✅ 正常な配信
- [ ] Sourcesタブで修正内容が含まれている
- [ ] Networkタブで200 OKで読み込まれている
- [ ] Consoleタブでログが表示される
- [ ] ドラッグ&ドロップで詳細ログが表示される
- [ ] add_cropリクエストが1回のみ
- [ ] 二重リクエストがブロックされる（発生した場合）

### ❌ 配信に問題がある場合
- [ ] 404エラーが表示される
- [ ] Sourcesタブで修正内容が含まれていない
- [ ] ログが全く表示されない
- [ ] add_cropリクエストが2回以上送信される

---

## 🎯 最終確認チェックリスト

配信確認を完了するには、以下をすべてチェックしてください：

- [ ] ブラウザで http://localhost:3000 にアクセスできる
- [ ] F12で開発者ツールが開ける
- [ ] Sourcesタブで `crop_palette_drag-*.js` が見つかる
- [ ] ファイル内に `DUPLICATE REQUEST BLOCKED` が含まれている
- [ ] ファイル内に `dataset.dragInitialized` が含まれている
- [ ] Consoleタブで初期化ログが表示される
- [ ] ドラッグ&ドロップで詳細ログが表示される
- [ ] Networkタブでadd_cropリクエストが1回のみ
- [ ] エラーが発生していない

すべてチェックできたら、配信は正常です！🎉

---

## 📝 補足情報

### Propshaftの仕組み
- `app/assets/javascripts/` 配下のファイルを自動検出
- ファイル内容のハッシュを生成（例: `85a4f3f4`）
- `/assets/ファイル名-ハッシュ.js` として配信
- キャッシュバスティングが自動的に機能

### デバッグモードの有効化
開発中はより詳細なログを確認できます：

```javascript
// ブラウザのConsoleで実行
localStorage.setItem('debug', 'crop_palette:*');
```

### 本番環境への注意
本番環境では以下を検討してください：

1. デバッグログの削除または無効化
2. `console.log` の最小化
3. ソースマップの無効化（必要に応じて）

---

**作成日**: 2025-10-19  
**最終更新**: 2025-10-19  
**ステータス**: ✅ 配信確認済み

