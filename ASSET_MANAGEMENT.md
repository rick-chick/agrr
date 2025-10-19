# アセット管理の仕組み - AGRR Project

## 概要

AGRRプロジェクトでは、Rails 8の推奨構成に従い、2つのアセット管理システムを使い分けています。

## 🎯 2つのアセット管理システム

### 1. jsbundling-rails (esbuild) - バンドル用

**用途**: npmライブラリのバンドル
- Leaflet（地図表示）
- Turbo & Stimulus（Hotwire）
- Chart.js（グラフ描画）
- Action Cable（WebSocket）

**場所**: 
- ソースコード: `app/javascript/` 配下
- ビルド出力: `app/assets/builds/` 配下（**直接編集禁止**）

**ビルドコマンド**:
```bash
npm run build
npm run build -- --watch  # ファイル監視モード
```

**ビルド内容**:
```bash
esbuild app/javascript/application.js \
  --bundle \
  --sourcemap \
  --format=esm \
  --outdir=app/assets/builds \
  --public-path=/assets \
  --external:*.png --external:*.jpg --external:*.jpeg --external:*.gif --external:*.svg
```

**出力ファイル**:
- `app/assets/builds/application.js` (約1.2MB)
- `app/assets/builds/application.css` (約13KB)
- `app/assets/builds/application.js.map` (ソースマップ)
- `app/assets/builds/application.css.map` (ソースマップ)

**ビュー側での読み込み**:
```erb
<%= javascript_include_tag "application", type: "module" %>
<%= stylesheet_link_tag "application" %>
```

### 2. Propshaft - 静的アセット配信

**用途**: ローカルの静的アセット（バンドルしない）
- プロジェクト固有のJavaScript
- スタイルシート
- 画像ファイル

**場所**:
- JavaScript: `app/assets/javascripts/` 配下
- CSS: `app/assets/stylesheets/` 配下
- 画像: `app/assets/images/` 配下

**特徴**:
- サブディレクトリ構造を維持
- フィンガープリント付きで配信
- 開発環境では `config.assets.compile = true` により動的に配信
- `@import`は使えない（個別読み込み必須）

**ビュー側での読み込み**:
```erb
<%= javascript_include_tag "custom_gantt_chart", defer: true %>
<%= stylesheet_link_tag "features/custom_gantt_chart" %>
```

## 📋 判断基準: どちらに置くか？

### `app/javascript/` に置くもの（esbuildでバンドル）

✅ npmパッケージを使うコード
✅ 複数ファイルをバンドルする必要があるコード
✅ トランスパイルが必要なコード

**例**:
- `fields.js` - Leaflet使用
- `temperature_chart.js` - Chart.js使用
- `cable_subscription.js` - Action Cable使用

### `app/assets/javascripts/` に置くもの（Propshaftで配信）

✅ プロジェクト固有のカスタムスクリプト
✅ npmライブラリに依存しないスタンドアロンのJavaScript
✅ 大きなファイル（バンドルに含めると重くなる）

**例**:
- `custom_gantt_chart.js` - 1354行の大きなファイル
- `crop_palette_drag.js` - 454行のカスタムスクリプト
- `crop_form.js` - フォーム制御
- `crop_selection.js` - セレクト制御
- `progress_bar.js` - プログレスバー

## 🚀 Docker起動時のアセット処理フロー

`docker compose up` を実行すると、以下の順序で処理されます：

### 1. 古いアセットのクリーンアップ
```bash
rm -rf /app/app/assets/builds/*
rm -rf /app/tmp/cache/assets/*
```

### 2. 初回ビルド（同期実行）
```bash
npm run build
```
- esbuildでJavaScript/CSSをバンドル
- 成功するまで次に進まない
- **失敗した場合、Railsサーバーは起動しない**

### 3. Watchモード起動（バックグラウンド）
```bash
npm run build -- --watch &
```
- ファイル変更を監視
- 変更があると自動的に再ビルド
- ログは `/tmp/esbuild-watch.log` に出力

### 4. Railsサーバー起動
```bash
bundle exec rails server -b 0.0.0.0
```

### 5. Propshaftによるアセット配信
- Railsが起動すると、Propshaftが `app/assets/` 配下のファイルを配信開始
- 開発環境では `config.assets.compile = true` により、リクエスト時に動的に配信

## ✅ 正常起動の確認方法

`docker compose up` を実行した際、以下のメッセージが表示されれば成功です：

```
=========================================
Building assets (JavaScript and CSS)...
=========================================

> build
> npx esbuild app/javascript/application.js ...

  app/assets/builds/application.js        1.2mb ⚠️
  app/assets/builds/application.css      12.8kb
  app/assets/builds/application.js.map    2.4mb
  app/assets/builds/application.css.map  24.2kb

⚡ Done in 162ms

✓ Initial asset build completed successfully

=========================================
Starting asset watcher for development...
=========================================
✓ Asset watcher is running (PID: xxx)
  Logs: /tmp/esbuild-watch.log
  Watching for file changes...

=========================================
Starting Rails server...
=========================================
```

## ❌ よくある間違い

### 1. `app/javascript/` にカスタムチャートコードを置いてバンドルに含める
❌ **間違い**: `app/javascript/custom_gantt_chart.js` を作成
✅ **正しい**: `app/assets/javascripts/custom_gantt_chart.js` に配置

### 2. Propshaftでnpmライブラリを配信しようとする
❌ **間違い**: `app/assets/javascripts/` にnpmパッケージをコピー
✅ **正しい**: `app/javascript/` で import して esbuild でバンドル

### 3. `app/assets/builds/` を直接編集する
❌ **間違い**: `app/assets/builds/application.js` を直接編集
✅ **正しい**: `app/javascript/application.js` を編集して再ビルド

### 4. PropshaftでCSS `@import` を使おうとする
❌ **間違い**: 
```css
/* app/assets/stylesheets/application.css */
@import "core/variables.css";
@import "components/navbar.css";
```
✅ **正しい**:
```erb
<!-- レイアウトファイルで個別読み込み -->
<%= stylesheet_link_tag "core/variables" %>
<%= stylesheet_link_tag "components/navbar" %>
```

## 🔍 トラブルシューティング

> **詳細なトラブルシューティング**: [docs/ASSET_LOADING_GUIDE.md](docs/ASSET_LOADING_GUIDE.md) を参照してください。  
> レイアウトファイルの確認方法、よくある間違いの詳細な解説があります。

### アセットが読み込まれない

1. **esbuildのビルド確認**:
```bash
docker compose exec web ls -lh /app/app/assets/builds/
```
`application.js` と `application.css` が存在するか確認

2. **Watchモードの確認**:
```bash
docker compose exec web cat /tmp/esbuild-watch.log
```

3. **Railsログの確認**:
```bash
docker compose logs web | grep -i "asset\|error"
```

### JavaScriptファイルを変更したのに反映されない

**esbuildでバンドルされるファイル**（`app/javascript/`）:
- Watchモードが正常に動いていれば自動的に再ビルド
- `/tmp/esbuild-watch.log` でビルド状況を確認

**Propshaftで配信されるファイル**（`app/assets/javascripts/`）:
- ブラウザのキャッシュをクリア（Ctrl+Shift+R）
- 開発環境では即座に反映されるはず

### ビルドエラーが発生する

1. **JavaScriptの構文エラー**:
```bash
docker compose exec web npm run build
```
でエラー内容を確認

2. **依存関係の問題**:
```bash
docker compose exec web npm install
docker compose restart web
```

## 📚 参考資料

- [Rails 8 Asset Pipeline Guide](https://edgeguides.rubyonrails.org/asset_pipeline.html)
- [Propshaft GitHub](https://github.com/rails/propshaft)
- [jsbundling-rails GitHub](https://github.com/rails/jsbundling-rails)
- [esbuild Documentation](https://esbuild.github.io/)

## 🎓 新しいJavaScriptファイルを追加する際のフロー

```
新しいJSファイルを作成
          ↓
┌─────────────────────┐
│ npmライブラリを使う？ │
└─────────────────────┘
      Yes ↓         No ↓
  ┌───────────┐    ┌────────────────────┐
  │ app/      │    │ 他のJSファイルと   │
  │ javascript│    │ バンドルする必要？ │
  └───────────┘    └────────────────────┘
        ↓               Yes ↓         No ↓
  application.js    ┌───────────┐    ┌───────────────┐
  でimport         │ app/      │    │ app/assets/   │
                   │ javascript│    │ javascripts/  │
                   └───────────┘    └───────────────┘
                        ↓                    ↓
                   application.js       レイアウトで
                   でimport           javascript_include_tag
```

## 📝 まとめ

### 起動時の確認ポイント

1. ✅ 初回ビルドが成功したか
2. ✅ Watchモードが起動したか
3. ✅ Railsサーバーが起動したか
4. ✅ ブラウザでアセットが読み込まれているか

### もう「開発が終わっているのか終わっていないのか」で議論しない

改善後のentrypointスクリプトにより：
- ビルドの進行状況が明確に表示される
- ビルド失敗時はRailsサーバーが起動しない
- Watchモードの状態が確認できる
- ログファイルで詳細なデバッグが可能

**これにより、起動時の状態が一目瞭然になります。**

