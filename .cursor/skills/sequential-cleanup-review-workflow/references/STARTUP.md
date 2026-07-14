# 起動 — slug と入口

**入口は常に `cleanup-workflow-tick.sh`。** A1 調査を親が始めるのは違反。

```bash
.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh \
  --parent-slug <slug>
```

## slug の選び方

| 状況 | やること | slug |
|------|----------|------|
| **今の未コミット変更**を初めて cleanup | tick のみ（**A1 に直行しない**） | 修正単位名から新規（例: `my-feature-foo`） |
| **別 PR / 別変更セット** | 上と同じ。**前の unit と混ぜない** | **必ず新 slug** |
| **外側 backlog 続き**（pending 残り） | `tick --parent-slug <既存slug>` | **既存 slug をそのまま** |
| [`github-issue-worker`](../../github-issue-worker/SKILL.md) §4 | tick のみ | `issue-<N>-<short-slug>`（ブランチ `issue/<N>-<short-slug>` から） |
| backlog TSV を初めて作る（D 後 ingest 用） | `backlog-init.sh`（**tick の代わりではない**） | 親 slug と同じ |

```bash
# 典型（今の変更を初めて cleanup）
SLUG=my-feature-foo
.cursor/skills/sequential-cleanup-review-workflow/scripts/cleanup-workflow-tick.sh \
  --parent-slug "$SLUG"
# → INNER_STEP=0 なら shell Step0 → advance → tick → INNER_STEP=A1 → Task 委譲 …
```

## tick 出力と次の一手

| tick 出力 | 親の次の一手 |
|-----------|----------------|
| `WORKFLOW_COMPLETE` | 完了報告可 |
| `TICK_PHASE=outer_pop` | shell 済み → **tick 再実行** |
| `TICK_PHASE=inner` + `INNER_STEP=A1` | **Task(explore, model=composer-2.5)** で A1 のみ |
| `INNER_STEP=0` + `RUN_SHELL=collect-…` | **Shell** で Step 0 → `inner-advance` → tick |
| その他 `INNER_STEP=…` | **Task 1 回** → `cleanup-inner-advance.sh` → tick |

## 禁止

- 「現在の変更分を確認し、クリーンアップを開始します」だけ言って **tick を実行しない**
- **A1 調査を親が始める**
- `backlog-init` だけで workflow 開始とみなす

## 参照

- [DUAL_LOOP.md](DUAL_LOOP.md) — while tasks + agent A1…D1 の正本
- [AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md) — Step 委譲・`model: composer-2.5`
