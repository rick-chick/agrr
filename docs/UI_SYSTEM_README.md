# UI System - 統一的な通知・ダイアログシステム

AGRRプロジェクトの通知・ダイアログUIを統一的に管理するシステムです。

## 🎯 なぜ作ったのか？

### 問題点
- ネイティブの `alert()`, `confirm()`, `prompt()` が使いにくい
- 各ファイルで独自のローディング表示を実装していて、コードが重複
- デザインが統一されていない
- メンテナンスが大変

### 解決策
トースト、スナックバー、ダイアログ、ローディングを**抽象化**し、統一的なAPIで提供します。

---

## 📦 提供するコンポーネント

### 1. **Toast**（トースト通知）
- 画面下部に表示される軽量な通知
- 自動的に消える（デフォルト4秒）
- 成功/エラー/警告/情報の4種類

### 2. **Snackbar**（スナックバー）
- アクション付きの重要な通知
- 画面下部に表示、やや長く表示（デフォルト6秒）
- 「元に戻す」などのアクションボタン付き

### 3. **Dialog**（ダイアログ）
- ネイティブ `alert/confirm/prompt` の代替
- モーダル表示、Promise ベース
- カスタマイズ可能

### 4. **Loading**（ローディング表示）
- 長時間かかる処理の進捗表示
- プログレスバー対応
- メッセージ更新可能

---

## 🚀 クイックスタート

### 基本的な使い方

```javascript
// 成功メッセージ
Notify.success('保存しました');

// エラーメッセージ
Notify.error('エラーが発生しました');

// 確認ダイアログ
const result = await Dialog.confirm('削除しますか？', { danger: true });
if (result.action === 'confirm') {
  // 削除処理
}

// ローディング表示
const loadingId = Loading.show('処理中...');
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

docs/
├── UI_SYSTEM_GUIDE.md      # 完全なAPIガイド
├── UI_SYSTEM_EXAMPLES.md   # 実装例集
└── UI_SYSTEM_README.md     # このファイル
```

すべてのレイアウトファイル（`application.html.erb`, `public.html.erb`, `admin.html.erb`, `auth.html.erb`）で自動的に読み込まれます。

---

## 🎨 デモページ

開発環境で以下のURLにアクセスすると、すべてのコンポーネントを試せます：

```
http://localhost:3000/demo/ui_system
```

---

## 📖 ドキュメント

### [UI_SYSTEM_GUIDE.md](./UI_SYSTEM_GUIDE.md)
完全なAPIリファレンス。すべてのメソッド、オプション、パラメータを網羅。

### [UI_SYSTEM_EXAMPLES.md](./UI_SYSTEM_EXAMPLES.md)
実践的な実装例集。既存コードの移行方法、パターン集など。

---

## 🔄 既存コードの移行

### Before（従来）

```javascript
// ❌ ネイティブダイアログ
alert('エラーが発生しました');

if (confirm('削除しますか？')) {
  deleteItem();
}

const name = prompt('名前を入力してください');

// ❌ 独自実装のローディング
function showLoadingOverlay(message) {
  const overlay = document.createElement('div');
  // ... 複雑な実装 ...
  document.body.appendChild(overlay);
}
```

### After（新規）

```javascript
// ✅ 統一されたAPI
Notify.error('エラーが発生しました');

const result = await Dialog.confirm('削除しますか？', { danger: true });
if (result.action === 'confirm') {
  deleteItem();
}

const nameResult = await Dialog.prompt('名前を入力してください');
if (nameResult.action === 'confirm') {
  console.log(nameResult.value);
}

// ✅ 共通ローディング
const loadingId = Loading.show('処理中...');
// ... 処理 ...
Loading.hide(loadingId);
```

---

## 🎯 設計思想

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
    ├── Toast (軽量・自動消去)
    ├── Snackbar (アクション付き)
    ├── Dialog (重要・モーダル)
    └── Loading (プログレス表示)
```

### デザインパターン

- **Strategy Pattern**: 表示方法を切り替え可能
- **Factory Pattern**: 通知オブジェクトを生成
- **Singleton Pattern**: グローバルな通知マネージャー
- **Queue Pattern**: 複数の通知を順序管理

---

## ✅ 利点

### 1. **統一された UX**
すべての通知が同じデザインと動作で表示されるため、ユーザー体験が向上

### 2. **コードの再利用**
ローディング表示などの実装を各ファイルで重複して書く必要がなくなる

### 3. **メンテナンス性の向上**
通知の見た目や動作を変更する際、1箇所を修正するだけで全体に反映

### 4. **型安全性（将来的にTypeScript化も可能）**
統一されたAPIなので、TypeScript化する際に型定義が容易

### 5. **テスト容易性**
共通コンポーネントなので、一度テストすれば全体で使える

---

## 🔧 カスタマイズ

### 色の変更

各システムは内部でCSSをインラインで定義していますが、必要に応じて `app/assets/stylesheets/shared/` にCSSファイルを作成して、より詳細なカスタマイズが可能です。

### アニメーション速度の調整

JavaScript内で定義されているアニメーション時間を調整できます：

- Toast/Snackbar: `slideInUp` 0.3秒
- Dialog: `dialogSlideUp` 0.3秒
- Loading: `fadeIn` 0.2秒

---

## 📝 TODO（今後の拡張予定）

- [ ] Banner（画面上部の永続的な通知）
- [ ] Inline Message（コンテキスト内の通知）
- [ ] カスタムアイコン対応
- [ ] サウンド通知
- [ ] 国際化対応（i18n連携）
- [ ] 既存の全 `alert/confirm/prompt` を置き換え
- [ ] TypeScript化

---

## 🤝 使用方法

すべてのレイアウトで自動的に読み込まれるので、特別な設定は不要です。
以下のグローバルAPIを使用してください：

- `Notify.success()`, `Notify.error()`, `Notify.warning()`, `Notify.info()`
- `Notify.snackbar()`
- `Dialog.alert()`, `Dialog.confirm()`, `Dialog.prompt()`
- `Loading.show()`, `Loading.hide()`, `Loading.showProgress()`, `Loading.updateProgress()`

---

## 📚 参考リンク

- [Material Design - Snackbars](https://material.io/components/snackbars)
- [Material Design - Dialogs](https://material.io/components/dialogs)
- [Human Interface Guidelines - Alerts](https://developer.apple.com/design/human-interface-guidelines/components/presentation/alerts)

---

## 📞 問い合わせ

質問や提案があれば、プロジェクトのIssueまたはPRで連絡してください。

**Happy Coding! 🎉**

