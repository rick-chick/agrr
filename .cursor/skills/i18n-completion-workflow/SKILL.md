---
name: i18n-completion-workflow
description: Completes Angular i18n migration end-to-end for this repository. Use when the user requests i18n対応, 翻訳漏れ洗い出し, ハードコーディング文字列の除去, 翻訳キー追加, or i18nの完遂確認.
---
# i18n Completion Workflow

Angular 側の i18n 対応手順。`assets/i18n/*.json` は手編集のみ（一括生成スクリプトは使わない）。

## 完遂の定義 (DoD)

1. 追加・変更した翻訳キーが `ja/en/in` に反映済み
2. 変更箇所に対応するテスト（カタログ spec 含む）が GREEN
3. テスト後の遅延テストチェックを実施
4. レビュー用レポート（対応一覧/残課題）を提示

## 前提

- `@ngx-translate`
- カタログ: `frontend/src/assets/i18n/{ja,en,in}.json`
- ルール: [i18n-completion-orchestrator.mdc](../../rules/i18n-completion-orchestrator.mdc)

### 翻訳キーの正

`assets/i18n/*.json` のみが実行時カタログ。`entrySchedule.*`, `nav.*` など意味ベースキーは参照がある限り残す。

## 実行フロー

### 1) 洗い出し

1. 対象画面・コンポーネントの TS/HTML を読む
2. `frontend/src` で日本語リテラル・英語直書き・`| translate` 未使用を検索
3. 既存キー流用可否を `assets/i18n/ja.json` で確認

### 2) 置換とキー追加

1. `translate` pipe または `TranslateService` に置換
2. キーは意味ベースで命名（ドメイン.画面.要素）
3. `ja` / `en` / `in` に同パスで追加
4. 必要なら `frontend/src/app/core/i18n/*-locale.spec.ts` 等にキー存在テストを追加

### 3) 検証

1. 関連 spec を `test-common` で実行
2. 個別 GREEN 後、フロント全体を `test-common` で実行
3. `test-slow-detection` を実施

### 4) 完了レポート

- 追加・変更した翻訳キー
- 置換した主要ファイル
- 実行テストと結果
- 残件（あれば理由付き）

## 禁止事項

- `rails test` / `npm test` の直接実行
- `ja` のみ更新して他言語を未更新のまま残す
- **補助レポートや `auto.*` だけに合わせて `assets/i18n` のキーを削除**
- **コード参照を検索せず**キー一括削除
- フロント JSON で **`%{...}` に戻す**（`{{param}}` を使う）
- 削除済みの `sync_i18n` / `extract-i18n` / `check-hardcoded-i18n` 等を復活させて JSON を一括書き換え

### 未使用キー削除（明示依頼時のみ）

1. `frontend/src` でキー文字列を検索
2. 参照ゼロを確認してから `ja` / `en` / `in` から同パスを削除
3. 削除一覧と検索根拠をレポートに記載
