# 二重ループ — 正本

## やりたい形

```text
while tasks:                    # shell — backlog / gate / pop / ingest / handoff
  agent do A1                   # Task 委譲（親は実装しない）
  agent do A2
  agent do B1
  …
  agent do D1
  agent/shell do D2
  → tasks                       # ingest + backlog 更新（shell）
```

| ループ | 誰 | 何 |
|--------|-----|-----|
| **`while tasks`** | **shell** | pending 数・pop・gate・ingest・handoff |
| **A1…D2** | **agent（Task 1 Step ずつ）** | 調査・実施・レビュー |
| **親オーケストレーター** | 親 AI | **tick を読んで** shell 実行 **または** 1 Step だけ Task 起動 |

**スクリプトだけでは A1 は実行できない**（監視・キュー・ゲートのみ）。  
**A1 を親が自分で調査開始するのも違う**（スキル起動直後に A1 に飛ぶ劣化）。

## 3 層（混同しない）

```
┌─ L1: shell（外側ゲート）──────────────────────────────────┐
│  backlog TSV / gate / pop / ingest / handoff / tick        │
└──────────────────────────────────────────────────────────┘
         ↓ 1 backlog item あたり
┌─ L2: 親オーケストレーター ─────────────────────────────────┐
│  tick 解釈 → shell 実行 or Task 1 Step 起動               │
│  自分で A〜D の編集・削除・テストはしない                   │
└──────────────────────────────────────────────────────────┘
         ↓ 各 Step
┌─ L3: ステップ専用サブエージェント ─────────────────────────┐
│  A1 explore / A2 generalPurpose / B1 explore / …          │
│  Task 起動は毎回 model: composer-2.5                        │
└──────────────────────────────────────────────────────────┘
```

| 層 | やる | やらない |
|----|------|----------|
| **L1 shell** | pending 数・pop・gate exit code | A〜D の実装・委譲 |
| **L2 親** | tick 解釈・**Step ごと委譲**・ゲート検証 | ソース編集・A〜D を 1 体で実施 |
| **L3 子** | 1 Step 分の調査 or 実施 | 次 Step・外側ループ・連鎖委譲 |

**劣化パターン**: L1 を入れたつもりが prompt が「内側 A→D 完走」だけで **L2/L3 を飛ばし 1 エージェント完遂に回帰**。

## 起動

[STARTUP.md](STARTUP.md) を正とする。

```bash
SKILL=.cursor/skills/sequential-cleanup-review-workflow/scripts
$SKILL/cleanup-workflow-tick.sh --parent-slug <slug>
```

## 親の同一ターン while（必須 — ユーザー発話待ち禁止）

**`gate` exit 0 まで同一ターンで止めない。** ユーザーに `prepare` / `next` を促してターン終了は **違反**。

```text
loop:
  out = shell: cleanup-workflow-tick.sh --parent-slug SLUG
  if out contains WORKFLOW_COMPLETE → break

  if out contains TICK_PHASE=inner and INNER_STEP=0:
    shell: RUN_SHELL from out
    shell: cleanup-inner-advance.sh --parent-slug SLUG --completed-step 0
    goto loop

  if out contains INNER_STEP in (A1,B1,C1,D1):
    Task explore readonly composer-2.5
    gate 表を検証
    shell: cleanup-inner-advance.sh --completed-step <step>
    goto loop

  if out contains INNER_STEP in (A2,B2,C2):
    Task generalPurpose or 層別, composer-2.5
    shell: cleanup-inner-advance.sh --completed-step <step>
    goto loop

  if out contains INNER_STEP in (B3,C3,D2):
    shell: test-common …
    shell: cleanup-inner-advance.sh --completed-step <step>
    if out contained INNER_DONE_RUN_SHELL → shell: cleanup-post-d.sh
    if backlog_id != main → shell: cleanup-agent-handoff.sh
    goto loop

  if out contains TICK_PHASE=outer_pop:
    goto loop
```

### 禁止出力（ターン停止 = 違反）

| 禁止 | 正 |
|------|-----|
| 「prepare で pop してください」 | 親が **shell: tick / next** を実行 |
| 「pending=11」だけ報告して停止 | **while gate** 継続 |
| 「優先度の高い残課題: …」で並べて停止 | pop 順 = **TSV 先頭**（AI 優先度なし） |
| 「別イテレーション向け」で backlog 除外 | **すべて ingest 済みなら全部 pop** |
| ユーザーに run 命令 | **オーケストレーターが Shell で run** |

## 禁止（ループ全体）

- スキル起動 → **いきなり A1 調査**（tick なし）
- **A〜D を 1 サブエージェント／1 ターンに丸投げ**
- tick が `INNER_STEP=A1` なのに **親が A1 の中身を実装**
- shell が tasks を進められるのに **ユーザーに prepare を促して停止**
- `gate` exit 1 で workflow 完了報告

## スクリプト

[SCRIPTS.md](SCRIPTS.md) を正とする。入口:

| スクリプト | 役割 |
|------------|------|
| `cleanup-workflow-tick.sh` | **入口** |
| `cleanup-inner-advance.sh` | 1 Step 完了後に進行 |
| `cleanup-post-d.sh` / `cleanup-agent-handoff.sh` | D2 後 ingest / 次 item |
| `run-outer-loop.sh gate` | 外側完了判定 |

## 参照

- [STARTUP.md](STARTUP.md) — slug・tick 出力
- [AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md) — 各 Step の agent プロンプト
- [MECHANICAL_OUTER_LOOP.md](MECHANICAL_OUTER_LOOP.md) — D1 ingest・backlog
