# アセットパイプライン（Rails HTML 側）

> **位置づけ**：Rails ERB / Hotwire 系（`app/javascript/`、`app/assets/javascripts/`）の運用メモ。Angular SPA（`frontend/`）はこの対象外。Hotwire スタックは段階的廃止予定（本番 UI は Angular SPA が正）。

## jsbundling-rails (esbuild)

- **用途**：npm ライブラリ（Leaflet、Turbo、Stimulus など）のバンドル
- **場所**：`app/javascript/` 配下
- **出力**：`app/assets/builds/`（esbuild 出力先。直接編集しない）
- **読み込み**：`<%= javascript_include_tag "application", type: "module" %>`

## Propshaft

- **用途**：ローカルの静的アセット（バンドルしない）
- **JavaScript**：`app/assets/javascripts/`
- **CSS**：`app/assets/stylesheets/`
- **画像**：`app/assets/images/`
- **読み込み**：
  - JS: `<%= javascript_include_tag "ファイル名", defer: true %>`
  - CSS: `<%= stylesheet_link_tag "ファイル名" %>`

## 判断フロー

1. npm ライブラリを使う、または他 JS とバンドルが必要 → `app/javascript/`（`application.js` で import）
2. それ以外 → `app/assets/javascripts/`（Propshaft で配信）

例：プロジェクト固有の Propshaft 配下スクリプト（ガント等のレガシー資産があった場合）。
