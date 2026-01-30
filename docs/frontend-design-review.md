# フロントコンポーネント デザイン見直し

Angular Material デザインスキル（`.cursor/skills/design-angular-material/SKILL.md`）に基づく見直しサマリとチェックリスト。

---

## 実施済み（2025-01）

### 1. デザイントークンの導入

- **場所**: `frontend/src/styles.css` の `:root`
- **内容**: 色・余白・角丸・タイポグラフィ・フォーカス用の CSS 変数を定義
- **ルール**: コンポーネントの CSS では **hex/rgb/px を直接書かず** `var(--token-name)` のみ使用する

### 2. ナビゲーション（navbar）の見直し

- **トークン化**: `navbar.component.css` をトークン参照に統一（色・余白・角丸・フォント）
- **セマンティクス**: `<nav>` 内のリンク群を `<ul class="nav-links">` + `<li>` に変更、`aria-label="メインナビゲーション"` を付与
- **a11y**: ドロップダウンに `aria-controls` / `id` / `role="menu"` / `role="menuitem"` を付与、全インタラクティブ要素に `:focus-visible` のアウトラインを定義

---

## 他コンポーネント向けチェックリスト（PR 前）

各コンポーネントの CSS/HTML を触る際に確認すること。

### トークン

- [ ] 色・余白・角丸がすべて `var(--color-*)` / `var(--space-*)` / `var(--radius-*)` になっている（生の hex/px なし）
- [ ] 不足トークンは `styles.css` の `:root` に追加してから使用している

### HTML・セマンティクス

- [ ] 見出し階層が飛んでいない（h1 → h2 → h3 の順）
- [ ] ナビ・一覧は `<ul>/<ol>` + `<li>` で表現している
- [ ] 遷移は `<a href>` / `routerLink`、アクションは `<button type="button|submit">` で使い分けている

### アクセシビリティ

- [ ] インタラクティブ要素に `:focus-visible` のスタイルがある（`outline` を消しっぱなしにしていない）
- [ ] アイコンのみのボタンに `aria-label` を付与している
- [ ] ドロップダウン・メニューに `aria-expanded` / `aria-haspopup` / `aria-controls` を適切に設定している

### 参照

- トークン一覧・スケール: `.cursor/skills/design-angular-material/references/DESIGN_TOKENS.md`
- デザインルール全体: `.cursor/skills/design-angular-material/SKILL.md`

---

## 今後の作業候補

- 各コンポーネントの CSS を順次トークン化（約 28 ファイルに hex/px のハードコードあり）
- リスト系コンポーネント（farm-list, crop-list 等）のセマンティクス・トークン適用
- 必要に応じて Angular Material 導入（現状は CDK のみ）し、テーマをトークンと連携
