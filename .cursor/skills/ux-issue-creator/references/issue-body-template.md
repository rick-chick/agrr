# Issue 本文テンプレート（AGRR UX/UI）

`rick-chick/agrr` の既存 issue（#21–#25）に合わせる。

## 必須セクション

```markdown
## 背景

<観測事実 1〜3 文。visual-review #N / file:line / PNG 名を明記>

## 対応

1. <具体的な修正方針>
2. <テスト方針（TDD）>

## 完了条件

- [ ] <観測可能な完了条件>
- [ ] 関連テスト GREEN（test-common）

## 依存

- なし
- または #N（理由・人間向けメモ）

（dispatch / retriage は本文・コメントの `#N` をパースしない。依存判断は Agent のみ。）

## 参照

- visual-review-results.md #N
- frontend/e2e/agent-review/out/<png>
- 関連コンポーネント path
```

## タイトル規約

```
[P0|P1|P2][UX|CSS|i18n|a11y] <pattern または component>: <短い要約>
```

| 区分 | 実装スキル（github-issue-worker 経由） |
|------|----------------------------------------|
| `[i18n]` | `i18n-completion-workflow` |
| `[UX]` | `tdd-on-edit` + キャプチャ再確認 |
| `[CSS]` | `frontend-css-route-audit` |
| `[a11y]` | `tdd-on-edit` + a11y spec |

## ラベル

| ラベル | いつ付けるか |
|--------|--------------|
| `enhancement` | UX/UI 改善の既定 |
| `bug` | 再現可能な誤表示・壊れた導線 |
| `documentation` | キャプチャ・レビュー更新のみ（実装なし） |
| `agent-ready` | 実装対象 issue の既定（方針未確定・議論中・`documentation` のみを除く） |

**禁止**: 根拠のない大量起票、同一 pattern の重複 issue、完了条件のない issue。
