# Dark Mode Policy（AGRR Frontend）

## Status

Accepted (2026-08-08) — Issue [#731](https://github.com/rick-chick/agrr/issues/731)

## 方針 (B): 将来対応＋セマンティックトークン設計

**現状**: AGRR は **ライトテーマのみ** を提供する。`frontend/src/styles.css` の `:root` が単一の色・余白トークンソースであり、`prefers-color-scheme: dark` や `data-theme` による上書きは **未実装**。

**決定**: ダークモードは **将来対応** とする（方針 A「永久非対応」は採用しない）。手動トグル UI（localStorage 永続化）は **別 issue** とし、初回実装スコープには含めない。

### 根拠

- #712 は誤った前提での起票のためクローズ済み。実装は未着手。
- トークン基盤（`:root` セマンティック変数、`audit:css-tokens:enforce`）は整備済みのため、後追いのテーマ切替コストを抑えられる。
- ガント・チャート全配色の最適化はスコープ外とし、段階的にシェル → マスタ → 計画画面の順で対応する。

## トークン設計方針（実装時）

1. **セマンティックトークンを維持** — コンポーネントは `--color-surface` / `--color-text` 等のみ参照。テーマごとに primitive 色（`--color-gray-*`）を直参照しない新規コードを増やさない。
2. **上書きは `styles.css` に集約** — `@media (prefers-color-scheme: dark) { :root { … } }` でセマンティックトークンを再マップする（方針 A: OS 追従のみ。手動トグルは将来 `data-theme` + 同じトークンマップの二重適用を検討）。
3. **`color-scheme`** — ダーク実装時に `html { color-scheme: light dark; }` を設定し、ネイティブフォーム・スクロールバーを OS と整合させる。
4. **コントラスト** — WCAG AA（通常テキスト 4.5:1、UI 3:1）を `prefers-color-scheme: dark` ブロック追加時に検証する。
5. **回帰防止** — `npm run audit:css-tokens:enforce` および `npm run check:btn-base-class:enforce` を GREEN のまま維持する。

## 最小実装スコープ（将来 issue）

次を満たした時点で「ダークモード初版」とする（**本 issue では実装しない**）:

- アプリシェル（ナビ・フッター・`app-main`）とマスタ `form-card` がダーク下で破綻しない
- フォーカスリング・ステータスバッジ・エラーパネル（`page-alert-error` / `MasterLoadErrorPanel`）が識別可能
- unit または visual spec でダークテーマ適用を 1 件以上検証

## スコープ外

- ユーザー設定画面でのテーマ手動切替（方針 B/C のトグル部分）
- ガント・気象チャートの全系列色のダーク最適化

## 参照

- `frontend/src/styles.css`
- `frontend/docs/design-system/COMPONENT-GUIDE.md`
- Issue #712（クローズ済み・再実装は新規 issue 可）
