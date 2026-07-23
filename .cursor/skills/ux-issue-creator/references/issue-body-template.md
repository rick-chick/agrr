# Issue 本文テンプレート（UX/UI）

```markdown
## 背景

<観測事実。visual-review #N / file:line / PNG>

## 再現手順

<画面・操作。起票前に PNG で確認済み>

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
