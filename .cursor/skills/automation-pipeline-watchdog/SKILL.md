---
name: automation-pipeline-watchdog
description: >-
  AGRR の issue / PR / dispatch workflow / bootstrap を 1 時間ごとに機械収集し、
  異常を調査して GitHub issue 化する。パイプライン監視、オートメーション自動修復、
  滞留 PR/issue の検知で適用。
---

# Automation Pipeline Watchdog（AGRR）

**Issue Worker / PR Merge Worker / dispatch workflows** の運用状態を **1 時間ごと**に機械収集し、**P0/P1 の異常**を調査して **GitHub issue** に落とす。repo 修正 PR は **最小限**（スクリプト破損など P0 のみ）。

上位原則: [JUDGMENT-CRITERIA.md](../automation-authoring/references/JUDGMENT-CRITERIA.md)、[`automation-authoring` PRINCIPLES.md §目的](../automation-authoring/references/PRINCIPLES.md)（人間介在なしで完遂。滞留を記録・再開せず未対応のまま残さない）。

週次の深い監査・クリティカル PR 修正は [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md) が担当。本スキルは **時間解像度の高い運用監視**に専念する。

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（cron） | 毎時 0 分 JST。直近 1〜2 時間の副作用を監視 |
| 手動 | 「パイプライン監視」「Automation watchdog」等 |

設定手順・prefill URL: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)（正本は [cloud-automation-audit の schedule](../cloud-automation-audit/references/cursor-automation-schedule.md)）

## 監視観点（機械収集）

`collect-pipeline-health.mjs` が次を JSON にまとめる（`tmp/pipeline-health-report.json`）。

| 観点 | 検知例 | 既定優先度 |
|------|--------|------------|
| **Issue** | `agent-in-progress` 90 分以上滞留 | P1 |
| **Issue** | `agent-ready` が 2 時間以上進まない（blocker なし） | P1 |
| **PR** | Draft が 12 時間以上 ready 化されない（CI green なのに滞留） | P1 |
| **PR** | `agent-merge-in-progress` 90 分以上 | P1 |
| **PR** | `BEHIND` / `CONFLICTING` のリンク PR（`closingIssuesReferences` あり） | P1 |
| **PR** | `BEHIND` / `CONFLICTING` + 未リンク（reconcile webhook 再送待ち） | 起票しない |
| **PR** | 必須 CI failure の open PR（ラベル不問） | P1 |
| **Workflow** | dispatch workflow の直近 2 時間以内の failure | P0 |
| **Bootstrap** | `cloud-gh-auth.sh` / `verify-skill-references.sh` / 単体 test 失敗 | P0 |

閾値の正本: [`scripts/collect-pipeline-health-lib.mjs`](scripts/collect-pipeline-health-lib.mjs)

## 1) 機械収集（毎回必須）

```bash
bash .cursor/scripts/cloud-gh-auth.sh
gh auth status
node .cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health.mjs
```

- `sources.githubLookupStatus === "failed"` → **issue 起票禁止**。Memory に失敗理由と Dashboard 手順（`AGRR_GH_PAT`）を記録して終了。
- `actionable` が 0 件 → Memory にサマリのみ書いて **終了**（PR も issue も開かない）。

## 2) 調査（actionable があるとき）

`actionable` の各 finding について:

1. **根拠を深掘り** — 該当 issue/PR のコメント、直近 Actions run、関連 dispatch workflow、labels の整合
2. **原因を一文で確定** — 推測語だけで終わらない（[`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc)）
3. **既存 issue との重複** — `existingIssueCandidates` で score ≥ 5 の OPEN があれば **起票しない**（コメント追記のみ可）

調査のみで解消済み（例: retry が直後に成功、一時的な CI flake で再実行 green）なら **起票しない**。Memory に「自己解消」と根拠を残す。

## 3) Issue 起票

**Automation 実行時は起票許可あり**（手動の `github-issue-creator` §4 確認は不要）。ただし根拠・完了条件は必須。

| 条件 | 動作 |
|------|------|
| P0/P1 かつ重複なし | `gh issue create` 可（**1 実行あたり最大 3 件**） |
| P2 のみ | 既定は **Memory 記載のみ**（起票は調査で人間判断が要る場合） |
| repo 側の明確な 1 行修正（スクリプト typo 等） | **最小 PR** 可（TDD 対象なら [`tdd-on-edit`](../tdd-on-edit/SKILL.md)） |

### ラベル

```bash
gh label create automation-watchdog --repo rick-chick/agrr \
  --color 5319E7 --description "Filed by automation-pipeline-watchdog" 2>/dev/null || true
```

- 既定: `bug` または `enhancement` + **`automation-watchdog`**
- **`agent-ready` は付けない**（運用調査 issue。実装タスクに昇格させる場合のみ人間が付与）

### 本文テンプレート

[`github-issue-creator` の汎用テンプレ](../github-issue-creator/references/issue-body-template.md) に加え、次を必ず含める:

```markdown
## 観測（watchdog）

- finding id: `<id>`
- 収集時刻: `<generatedAt>`
- 機械サマリ: `<summary>`

## 再現手順

<同 finding を機械収集で再現する手順。ログ URL、workflow run、label 状態>

## 完了条件

- [ ] 根本原因が解消され、同 finding id が 2 回連続の hourly run で再発しない
- [ ] 必要なら dispatch / retry / secrets / Automation 設定を doc 正本に反映
```

## 4) 終了レポート（Memory 必須）

```markdown
## Pipeline Watchdog — YYYY-MM-DD HH:00 JST

### 収集
- githubLookupStatus: ok / failed / skipped
- findings: N（actionable: M）

### 調査・起票
| finding id | 結果 | issue / PR |
|------------|------|------------|
| … | issue #N / skipped duplicate / self-resolved | … |

### 実施した修正
- （なし）または PR #N
```

**actionable 0・起票 0・PR 0** でも Memory に 3 行サマリを残す。

## 5) 禁止

- 根拠のない issue 量産
- `githubLookupStatus: failed` 時の起票
- 重複 score ≥ 5 を確認せずに起票
- `agent-ready` の自動付与（運用 issue を Issue Worker に流す）
- 積極的リファクタ・プロンプト改善・cron 変更
- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md) の週次監査の代替

## 関連

- 週次監査: [`cloud-automation-audit`](../cloud-automation-audit/SKILL.md)
- スケジュール正本: [`cursor-automation-schedule.md`](../cloud-automation-audit/references/cursor-automation-schedule.md)
- Issue 起票品質: [`github-issue-creator`](../github-issue-creator/SKILL.md)
- 全体俯瞰: [`docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md`](../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md)

---

## Automation（スケジュール）

Cloud Agent 向け。**毎時**パイプラインを機械監視し、異常を調査して issue 化。

### トリガー

| cron | 意味 |
|------|------|
| `0 * * * *` | 毎時 0 分 JST |

設定手順・prefill URL: [cloud-automation-audit/references/cursor-automation-schedule.md](../cloud-automation-audit/references/cursor-automation-schedule.md)

### Tools

- **Pull request creation**: OFF（P0 の最小 repo 修正のみ例外で ON 可）
- **Memories**: ON 必須

### 実行フロー

1. SKILL §1 — `collect-pipeline-health.mjs` 実行
2. `actionable` 0 → §4 Memory のみで終了
3. 各 actionable を §2 調査
4. §3 で issue 起票（最大 3 件）または自己解消記録
5. §4 Memory レポート

### Automation 用プロンプト（コピペ）

```
You are the AGRR Automation Pipeline Watchdog for repository rick-chick/agrr.

Read and follow `.cursor/skills/automation-pipeline-watchdog/SKILL.md` exactly.

Hourly run:
1. Run `node .cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health.mjs`
2. Read `tmp/pipeline-health-report.json`
3. If sources.githubLookupStatus === "failed", record failure in memory and exit without creating issues.
4. For each item in `actionable`, investigate root cause using gh/API/logs. Skip self-resolved or duplicate findings (existingIssueCandidates score >= 5 OPEN).
5. Create up to 3 GitHub issues for confirmed P0/P1 problems (labels: bug or enhancement + automation-watchdog; do NOT add agent-ready).
6. Open a PR only for minimal P0 repo fixes (broken scripts). Otherwise no PR.
7. Write the §4 memory report every run.
```
