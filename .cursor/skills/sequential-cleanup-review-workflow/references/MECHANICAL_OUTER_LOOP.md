# 機械的外側ループ（AI 判断禁止）

**外側ループの backlog 化・pop・dispatch・完了判定は shell のみ。** エージェントは「割り当てられた 1 item を実行して handoff」だけ。

## 定義

**D1 レビューで挙がった候補は、例外なくすべて backlog 行になる。**  
「必須か」「任意改善か」「同一サイクルか」「スコープ外か」は **エージェントが判断しない**。shell が ingest する。

| 処理 | 誰 | AI 判断 |
|------|-----|---------|
| D レビューで見つかった **すべて** の行 | D1 → TSV ファイル | 記載のみ（取捨選択しない） |
| TSV → backlog | `backlog-ingest-d-review.sh` | **なし** |
| 次 item 選択 | `backlog-pop.sh`（先頭 pending） | **なし** |
| エージェント起動 | dispatch / webhook / GHA | **なし** |
| 完了判定 | `gate` exit code | **なし** |
| item 改修 + 内側 A1→…→D2 | L2/L3 エージェント | 実装のみ |

**deferred / optional / 別タスク / スコープ外** — エージェントが理由にして **中断・確認・完了報告してはならない**。

## フロー

```
内側 D1 → tmp/cleanup-d-review-<slug>.tsv（全行）
       → backlog-ingest-d-review.sh（全行 pending 化）
       → run-outer-loop.sh run-mechanical / handoff 連鎖
              ↓
       エージェント 1 item（L2 委譲 + 内側 Step 委譲）
              ↓ 必須
       cleanup-agent-handoff.sh（mark-done + 次 dispatch）
              ↓ 繰り返し
       gate exit 0
```

内側で C2 ↔ D1 により **すでに直した** 項目があっても、D1 がレビューで挙げたなら **TSV に行として残す**（`done` 更新は handoff のみ）。

## ファイル正本

| パス | 役割 |
|------|------|
| `tmp/cleanup-d-review-<slug>.tsv` | D1 出力（**すべての候補**） |
| `tmp/cleanup-backlog-<slug>.tsv` | backlog 正本（ingest が書く） |
| `tmp/cleanup-backlog-<slug>.md` | render（**編集禁止**） |
| `tmp/cleanup-next-<slug>-<id>.md` | `prepare` が生成する 1 item 指示 |

## D1 TSV 形式

`tmp/cleanup-d-review-<parent-slug>.tsv`:

```
id	kind	summary	evidence	source
C1-1	ARCHITECTURE	presenter callback 逆依存	禁止 12, file:line	C1
	契約	R4 DELETE undo 観測不足	契約テストなし	D1
```

- **空 id** → ingest が `R1`, `R2`, … を付与
- **すべての行** を ingest

## 禁止される判断（ワークフロー違反）

エージェントが backlog / TSV から **除外** してよい理由は **ない**:

| 禁止フレーズ（例） | なぜ違反 |
|--------------------|----------|
| 「同一サイクル要修正＝いいえ」 | 同一サイクル列は **AI が付けない** |
| 「任意改善であり残課題に該当しない」 | **任意 / 必須の区分を AI がしてはならない** |
| 「REMAINING_ISSUES のマージ前必須に該当しない」 | 該当可否は AI の判断材料にしない |
| 「外側スタックには積まない」 | 積むのは **ingest.sh** |
| 「fragment ヘルパー分離はスコープ外」 | スコープ外でも **TSV 行 → ingest** |
| 「deferred / 別タスク / optional」 | strict 既定で **pending** |

**D1 で口頭・markdown レビューに書いた候補が TSV/backlog に無い** → D 未完了。

### 禁止例

> D1 で挙がった候補は任意改善であり、REMAINING_ISSUES のマージ前必須に該当しないため、外側スタックには積んでいません。

**正**: TSV に行追加 → `cleanup-post-d.sh` → 親が **同一ターン while gate**。

> 外側ループ — 未完了。pending=11。続ける場合は prepare で pop してください。

**正**: 親が **shell: tick / next** → L2 Step 委譲 → `handoff` → loop（[DUAL_LOOP.md](DUAL_LOOP.md)）。

## コマンド

```bash
PARENT=plan-work-ux
SKILL=.cursor/skills/sequential-cleanup-review-workflow/scripts

# D2 直後（取捨選択しない）
"$SKILL/backlog-ingest-d-review.sh" --parent-slug "$PARENT"
"$SKILL/run-outer-loop.sh" --parent-slug "$PARENT" run-mechanical

# エージェント終了時（必須）
"$SKILL/cleanup-agent-handoff.sh" --parent-slug "$PARENT" --id C1-1

# 完了報告前
"$SKILL/run-outer-loop.sh" --parent-slug "$PARENT" gate
```

スクリプト一覧: [SCRIPTS.md](SCRIPTS.md)

## deferred の扱い

| モード | 挙動 |
|--------|------|
| **strict（既定）** | `deferred` → `pending`。エージェントは消化必須 |
| `CLEANUP_ALLOW_DEFER=1` | import 時のみ deferred → `done`（**規約上の障害**またはユーザー明示時） |

エージェントが markdown に `deferred（別タスク）` と書いても、**import / strict では pending に戻る**。

## 完了条件

`run-outer-loop.sh gate` **exit 0** のみ workflow 完了報告可:

- backlog TSV に `pending` / `in_progress` = 0
- 直近 D1 の候補が TSV に書かれ ingest 済み

## 環境変数・Automation

| 変数 | 用途 |
|------|------|
| `CLEANUP_OUTER_LOOP_WEBHOOK_URL` | Cursor Automation webhook |
| `CLEANUP_OUTER_LOOP_WEBHOOK_KEY` | Bearer token |

GitHub Actions: `.github/workflows/cleanup-outer-loop-dispatch.yml`

## 内側ループ（L2/L3）

外側を機械化しても **内側は Step 委譲必須**（[AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md)）。混同しない。

## やらないこと

- エージェントが backlog TSV/md を手編集
- D1 が理由付けで TSV/backlog から **候補を落とす**
- 「外側スタックには積んでいません」報告（**ingest しろ**）
- ingest 前に AI が backlog をフィルタ
- handoff なしで「続けますか？」
- `gate` exit 1 で workflow 完了報告
- **「優先度の高い残課題」一覧だけ出して停止**
