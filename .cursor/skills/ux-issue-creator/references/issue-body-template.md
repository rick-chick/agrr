# Issue 本文テンプレート（UX/UI）

```markdown
## 背景

<観測事実。visual-review #N / captureRunId / file:line / spec 名>

## 再現手順

<画面・操作。視覚指摘は captureRunId 紐づけ PNG。機械指摘は spec / audit コマンド>

## 根拠

- captureRunId: `<agent-review-bundle.json の runId>`（視覚指摘のみ）
- または: `<spec ファイル / audit コマンド>`

## 完了条件

- [ ] <観測可能>
- [ ] test-common GREEN

## 依存

- なし

## 参照

- visual-review-results.md #N
- frontend/e2e/agent-review/out/<png>
- コンポーネント: `path/to/file`
```

## タイトル

```
[P0|P1|P2][UX|CSS|i18n|a11y] <pattern>: <要約>
```

## ラベル

| ラベル | 条件 |
|--------|------|
| `enhancement` | UX/UI 改善の既定 |
| `bug` | 再現済みの誤表示・壊れた導線 |
| `documentation` | キャプチャ・レビュー更新のみ |
| `agent-ready` | 実装対象（方針未確定・`documentation` を除く） |
