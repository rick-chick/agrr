# UI System Guide - 通知・ダイアログシステム

AGRRプロジェクトで使用する統一的なUI通知システムのガイドです。

## 📋 概要

従来のブラウザネイティブの `alert()`, `confirm()`, `prompt()` や、各ファイルで独自実装されていたローディング表示を統一し、モダンで一貫性のあるUIを提供します。

### 設計思想

1. **Strategy Pattern**: 表示方法を切り替え可能（Toast/Snackbar/Dialog/Loading）
2. **Queue Management**: 複数の通知を順序管理
3. **Severity Levels**: success/error/warning/info の統一
4. **Lifecycle Control**: show → display → dismiss のライフサイクル管理

### 抽象化の階層

```
Notification System (通知システム)
├── Notification Manager (管理層)
│   ├── Queue Management (キュー管理)
│   ├── Priority Handling (優先度制御)
│   └── Lifecycle Control (ライフサイクル制御)
│
├── Notification Types (種別層)
│   ├── Severity Level (重要度: success/error/warning/info)
│   ├── Persistence (永続性: temporary/persistent/action-required)
│   └── User Action (ユーザーアクション: dismissable/auto-dismiss/interactive)
│
└── Presentation Strategy (表示戦略層)
    ├── Toast (軽量・自動消去・画面下部)
    ├── Snackbar (アクション付き・画面下部)
    ├── Dialog (重要・モーダル)
    └── Loading (プログレス表示)
```

---

## 🎯 コンポーネント一覧

### 1. Toast（トースト通知）

**用途**: 軽量な成功/エラー/警告/情報メッセージ  
**特徴**: 画面下部に表示、自動消去（デフォルト4秒）、スタック表示

#### API

```javascript
// 成功メッセージ
Notify.success('保存しました');

// エラーメッセージ（6秒表示）
Notify.error('エラーが発生しました');

// 警告メッセージ
Notify.warning('注意してください');

// 情報メッセージ
Notify.info('処理を開始しました');

// カスタムオプション
Notify.success('保存しました', {
  duration: 3000, // 表示時間（ミリ秒）
  action: {
    text: '元に戻す',
    callback: () => { /* 処理 */ }
  }
});
```

#### 使用例

```javascript
// フォーム保存成功
form.addEventListener('submit', async (e) => {
  e.preventDefault();
  try {
    await saveData();
    Notify.success('データを保存しました');
  } catch (error) {
    Notify.error('保存に失敗しました: ' + error.message);
  }
});

// アクション付き通知
Notify.success('作物を削除しました', {
  action: {
    text: '元に戻す',
    callback: () => {
      undoDelete();
      Notify.info('削除を取り消しました');
    }
  }
});
```

---

### 2. Snackbar（スナックバー）

**用途**: アクション付きの重要な通知  
**特徴**: 画面下部に表示、やや永続的（デフォルト6秒）、アクションボタン

#### API

```javascript
Notify.snackbar('作物を削除しました', {
  type: 'success', // success/error/warning/info
  action: {
    text: '元に戻す',
    callback: () => { /* 処理 */ }
  }
});
```

#### 使用例

```javascript
// 削除操作と元に戻す
deleteButton.addEventListener('click', async () => {
  const deletedItem = await deleteItem(itemId);
  
  Notify.snackbar('アイテムを削除しました', {
    type: 'success',
    action: {
      text: '元に戻す',
      callback: async () => {
        await restoreItem(deletedItem);
        Notify.success('削除を取り消しました');
      }
    }
  });
});
```

---

### 3. Dialog（ダイアログ）

**用途**: ネイティブ `alert()`, `confirm()`, `prompt()` の代替  
**特徴**: モーダル表示、Promise ベース、カスタマイズ可能

#### 3.1 Alert（通知ダイアログ）

```javascript
// 基本的な使い方
await Dialog.alert('保存が完了しました');

// タイトル付き
await Dialog.alert('データの読み込みに失敗しました', 'エラー');
```

#### 3.2 Confirm（確認ダイアログ）

```javascript
// 基本的な使い方
const result = await Dialog.confirm('本当に削除しますか？');
if (result.action === 'confirm') {
  // 削除処理
}

// カスタマイズ
const result = await Dialog.confirm('この操作は取り消せません。続けますか？', {
  title: '重要な確認',
  confirmText: '削除する',
  cancelText: 'キャンセル',
  danger: true // 赤い確認ボタン
});

if (result.action === 'confirm') {
  deleteItem();
}
```

#### 3.3 Prompt（入力ダイアログ）

```javascript
// 基本的な使い方
const result = await Dialog.prompt('圃場名を入力してください');
if (result.action === 'confirm') {
  console.log('入力値:', result.value);
}

// カスタマイズ
const result = await Dialog.prompt('面積（㎡）を入力してください', {
  title: '圃場の追加',
  defaultValue: '100',
  placeholder: '例: 1000',
  type: 'number',
  confirmText: '追加',
  cancelText: 'キャンセル'
});

if (result.action === 'confirm' && result.value) {
  addField(result.value);
}
```

#### 使用例

```javascript
// 従来の書き方（非推奨）
if (confirm('本当に削除しますか？')) {
  deleteItem();
}

// 新しい書き方（推奨）
const result = await Dialog.confirm('本当に削除しますか？', {
  title: '削除の確認',
  danger: true
});

if (result.action === 'confirm') {
  try {
    await deleteItem();
    Notify.success('削除しました');
  } catch (error) {
    Notify.error('削除に失敗しました');
  }
}
```

---

### 4. Loading（ローディング表示）

**用途**: 長時間かかる処理の進捗表示  
**特徴**: オーバーレイ表示、プログレスバー対応、メッセージ更新可能

#### API

```javascript
// 基本的なローディング
const loadingId = Loading.show('処理中...');
// ... 処理 ...
Loading.hide(loadingId);

// プログレス付き
const loadingId = Loading.showProgress('最適化処理中...', 0);
Loading.updateProgress(loadingId, 50); // 50%
Loading.updateProgress(loadingId, 100, '完了しました'); // メッセージも更新
Loading.hide(loadingId);

// メッセージ更新
Loading.updateMessage(loadingId, '圃場データを取得中...', '残り30秒');
```

#### 使用例

```javascript
// 基本的な使い方
async function optimizePlan() {
  const loadingId = Loading.show('最適化処理中...');
  
  try {
    await performOptimization();
    Loading.hide(loadingId);
    Notify.success('最適化が完了しました');
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error('最適化に失敗しました');
  }
}

// プログレス表示付き
async function processWithProgress() {
  const loadingId = Loading.showProgress('データ処理中...', 0);
  
  for (let i = 0; i <= 100; i += 10) {
    await processChunk(i);
    Loading.updateProgress(loadingId, i);
  }
  
  Loading.hide(loadingId);
  Notify.success('処理が完了しました');
}

// 段階的なメッセージ更新
async function multiStepProcess() {
  const loadingId = Loading.show('処理を開始しています...');
  
  Loading.updateMessage(loadingId, '圃場データを取得中...');
  await fetchFieldData();
  
  Loading.updateMessage(loadingId, '作物データを取得中...');
  await fetchCropData();
  
  Loading.updateMessage(loadingId, '最適化を実行中...');
  await optimize();
  
  Loading.hide(loadingId);
  Notify.success('すべての処理が完了しました');
}
```

---

## 🔄 既存コードの移行

### alert() の置き換え

```javascript
// 従来
alert('エラーが発生しました');

// 新規（軽量な通知）
Notify.error('エラーが発生しました');

// 新規（ダイアログとして表示）
await Dialog.alert('エラーが発生しました', 'エラー');
```

### confirm() の置き換え

```javascript
// 従来
if (confirm('本当に削除しますか？')) {
  deleteItem();
}

// 新規
const result = await Dialog.confirm('本当に削除しますか？', {
  danger: true
});
if (result.action === 'confirm') {
  deleteItem();
}
```

### prompt() の置き換え

```javascript
// 従来
const name = prompt('圃場名を入力してください', '圃場1');
if (name) {
  addField(name);
}

// 新規
const result = await Dialog.prompt('圃場名を入力してください', {
  defaultValue: '圃場1'
});
if (result.action === 'confirm' && result.value) {
  addField(result.value);
}
```

### カスタムローディングの置き換え

```javascript
// 従来（custom_gantt_chart.js など）
function showLoadingOverlay(message) {
  const overlay = document.createElement('div');
  overlay.id = 'reoptimization-overlay';
  // ... 独自実装 ...
  document.body.appendChild(overlay);
}

function hideLoadingOverlay() {
  const overlay = document.getElementById('reoptimization-overlay');
  overlay?.remove();
}

// 新規
const loadingId = Loading.show('最適化処理中...');
// ... 処理 ...
Loading.hide(loadingId);
```

---

## 📁 ファイル構成

```
app/assets/javascripts/shared/
├── notification_system.js  # Toast/Snackbar
├── dialog_system.js        # Alert/Confirm/Prompt
└── loading_system.js       # Loading表示
```

すべてのファイルは `app/views/layouts/application.html.erb` で自動的に読み込まれます。

---

## 🎨 カスタマイズ

### 色の変更

各システムは内部でCSSをインラインで定義していますが、必要に応じて `app/assets/stylesheets/shared/` にCSSファイルを作成して、より詳細なカスタマイズが可能です。

### アニメーションの調整

アニメーション時間はJavaScript内で定義されています：

- Toast/Snackbar: 画面下からスライドイン（0.3秒）
- Dialog: 下から上にスライドアップ（0.3秒）
- Loading: フェードイン（0.2秒）

---

## ✅ ベストプラクティス

### 1. 適切なコンポーネントの選択

| 状況 | 推奨コンポーネント |
|------|-------------------|
| 成功メッセージ | `Notify.success()` |
| エラーメッセージ | `Notify.error()` |
| 削除確認 | `Dialog.confirm({ danger: true })` |
| 入力受付 | `Dialog.prompt()` |
| 長時間処理 | `Loading.show()` または `Loading.showProgress()` |
| 元に戻す操作 | `Notify.snackbar({ action: ... })` |

### 2. エラーハンドリング

```javascript
async function saveData() {
  const loadingId = Loading.show('保存中...');
  
  try {
    await api.save(data);
    Loading.hide(loadingId);
    Notify.success('保存しました');
  } catch (error) {
    Loading.hide(loadingId);
    Notify.error(`保存に失敗しました: ${error.message}`);
    console.error(error);
  }
}
```

### 3. 非同期処理との組み合わせ

```javascript
// ❌ 悪い例：ローディングを隠し忘れる可能性
const loadingId = Loading.show('処理中...');
await doSomething();
Loading.hide(loadingId);

// ✅ 良い例：try-finally で確実に隠す
const loadingId = Loading.show('処理中...');
try {
  await doSomething();
} finally {
  Loading.hide(loadingId);
}
```

### 4. 通知の乱発を避ける

```javascript
// ❌ 悪い例：ループ内で通知を連発
items.forEach(item => {
  processItem(item);
  Notify.success('処理しました'); // 多すぎる！
});

// ✅ 良い例：まとめて通知
const count = items.length;
items.forEach(item => processItem(item));
Notify.success(`${count}件の処理が完了しました`);
```

---

## 🔧 トラブルシューティング

### 通知が表示されない

1. ブラウザのコンソールでエラーを確認
2. JavaScript が正しく読み込まれているか確認
3. `window.Notify`, `window.Dialog`, `window.Loading` が定義されているか確認

```javascript
console.log(window.Notify); // undefined でなければOK
```

### 複数の通知が重なる

仕様です。最大3件まで同時表示され、それ以上はキューに入ります。すべて閉じたい場合：

```javascript
Notify.dismissAll();
```

### ローディングが消えない

ID を保持していない場合は、すべて消去：

```javascript
Loading.hideAll();
```

---

## 📚 参考

- [Material Design - Snackbars](https://material.io/components/snackbars)
- [Material Design - Dialogs](https://material.io/components/dialogs)
- [Human Interface Guidelines - Alerts](https://developer.apple.com/design/human-interface-guidelines/components/presentation/alerts)

---

## 🚀 今後の拡張予定

- [ ] Banner（画面上部の永続的な通知）
- [ ] Inline Message（コンテキスト内の通知）
- [ ] カスタムアイコン対応
- [ ] サウンド通知
- [ ] 国際化対応（i18n）

