---
name: sequential-cleanup-review-workflow
description: >-
  After each modification unit, removes dead code, moves or safe-deletes out-of-layer
  tests and component code, then reviews before the next unit—not batched at PR end.
  Use when the user asks for 順次改修後の整理, 責務外テストの移動, セーフ削除,
  コンポーネント責務外の移動, 改修後レビュー, or names this skill during feature/refactor work.
disable-model-invocation: true
---

# 順次クリーンアップ・レビュー（AGRR）

## 適用

- **修正単位**ごとに本ループを **1 回** 回す（CA 内側・単発改修・Phase 内いずれも）。
- **後片付けを PR 末にまとめない。**
- 自動起動しない（`disable-model-invocation: true`）。ユーザーがスキル名またはトリガ語で明示したときのみ。
- **例外**: [`github-issue-worker`](../github-issue-worker/SKILL.md) の実装経路では TDD GREEN 後 **必須**。

## 起動（必須 — tick 未実行で A1 に進まない）

```bash
.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh \
  --parent-slug <slug>
```

```text
while tasks:           # shell（backlog / gate / pop / ingest / handoff）
  agent A1 → agent A2 → … → agent D1 → D2
  → tasks
```

- slug・tick 出力: [references/STARTUP.md](references/STARTUP.md)
- ループ・3 層・同一ターン until gate: [references/DUAL_LOOP.md](references/DUAL_LOOP.md)
- Step 委譲（`model: composer-2.5` 必須）: [references/AGENT_ORCHESTRATION.md](references/AGENT_ORCHESTRATION.md)
- D1 ingest（全行・AI 取捨選択禁止）: [references/MECHANICAL_OUTER_LOOP.md](references/MECHANICAL_OUTER_LOOP.md)

## References

| ファイル | 内容 |
|----------|------|
| [STARTUP.md](references/STARTUP.md) | slug 選定・tick 入口 |
| [DUAL_LOOP.md](references/DUAL_LOOP.md) | while tasks · L1/L2/L3 · 親 while |
| [MECHANICAL_OUTER_LOOP.md](references/MECHANICAL_OUTER_LOOP.md) | backlog · D1 TSV ingest · gate |
| [AGENT_ORCHESTRATION.md](references/AGENT_ORCHESTRATION.md) | Step 委譲・ゲート |
| [STEPS_ABCD.md](references/STEPS_ABCD.md) | A/B/C/D 作業内容 |
| [CHECKLIST.md](references/CHECKLIST.md) | 進捗表・判定木 |
| [SCRIPTS.md](references/SCRIPTS.md) | スクリプト一覧 |
| [RULES.md](references/RULES.md) | 原則・禁止・他スキル |

原則・やらないことの全文は [RULES.md](references/RULES.md) を正とする。
