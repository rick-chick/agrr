---
name: cloud-automation-audit
description: >-
  AGRR の Cursor Cloud Automation 実行結果を監査し、スキル・スクリプト・認証・Webhook 配線の
  クリティカルな不具合のみを修正する。積極的改善は行わない。
  Cloud Automation 監査、Automation 実行結果レビュー、Automation ヘルスチェックで適用。
---

# Cloud Automation 監査（AGRR）

登録済み Cursor Automation の**実行結果と依存物**を監査し、**壊れている・動いていない**ものだけを直す。**改善提案・最適化・プロンプト磨き込みは行わない**。

## 起動元

| 経路 | 挙動 |
|------|------|
| Cursor Automation（cron） | 毎週金曜 10:00 JST。直近 1 週間の実行を監査 |
| 手動 | 「Automation 監査」「Cloud Automation の実行結果を確認」等 |

設定手順・prefill URL: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)

## 監査対象（レジストリ）

[references/cursor-automation-schedule.md](references/cursor-automation-schedule.md) の一覧が正。

| 名前 | スキル | cron | 期待する成果 |
|------|--------|------|--------------|
| **Issue Worker** | `github-issue-worker` | `0 9 * * 1-5` | 実装 PR または close / blocked / 対象なし |
| **PR Merge Worker** | `github-pr-merge-worker` | イベント（PR / CI） | squash マージ / 同一ブランチ修正 / skip / blocked |
| **UX Issue Audit** | `ux-issue-pipeline` § Automation | `0 9 * * 1` | 条件付き issue 起票 or スキップ記録 |
| **Automation Audit** | `cloud-automation-audit`（本スキル） | `0 10 * * 5` | 監査レポート。クリティカル時のみ PR |

**1 回の実行 = 監査レポート 1 件**。複数 Automation を横断して 1 レポートにまとめる。

## 1) 実行結果の収集

Cloud Agent は**他 Automation の run ログ・Memory にアクセスできない**（API なし、Memory は automation ごとに隔離）。

**第一情報源**（毎回必ず実行）: **§1B GitHub 副作用** + **§1C 依存物スモーク** + **自 Automation の Memory**（前回監査レポート）。

詳細チェックリスト: [references/AUDIT-CHECKLIST.md](references/AUDIT-CHECKLIST.md)

### A. 他 Automation の run ログ（補助・人間向け）

Cloud Agent 単体では取得不可。人間が [cursor.com/automations](https://cursor.com/automations) で直近 7 日を確認する場合の目安:

- **Failed / Error** — §1B/C で裏取りし、repo 側根因なら P0
- **Succeeded + 期待どおりのスキップ** — **正常。修正しない**

各 Automation（Issue Worker / UX Audit）は**自分の Memory** に失敗・スキップ理由を書く運用を推奨。監査側はそれを読めないため、§1B で間接確認する。

### B. GitHub 副作用（第一情報源・毎回）

```bash
# Issue Worker: 直近 7 日の automation 由来 PR（author は cursor または作成者アカウント）
gh pr list --repo rick-chick/agrr --state all --limit 20 --json number,title,author,createdAt,state

# agent-blocked / agent-in-progress の滞留
gh issue list --repo rick-chick/agrr --label agent-blocked --state open --json number,title,updatedAt
gh issue list --repo rick-chick/agrr --label agent-in-progress --state open --json number,title,updatedAt

# UX Audit: 直近 7 日の [P0]/[P1] UX/i18n/CSS 起票
gh issue list --repo rick-chick/agrr --state all --limit 30 --search "created:>=YYYY-MM-DD label:agent-ready"
```

日付 `YYYY-MM-DD` は run 日から 7 日前。

### C. 依存物スモーク（第一情報源・毎回）

```bash
# Cloud bootstrap
bash .cursor/scripts/cloud-gh-auth.sh
gh auth status
gh issue list --repo rick-chick/agrr --limit 1

# UX Audit 前提ファイル（欠落時は UX Audit が本番パスでクラッシュ）
test -f frontend/e2e/agent-review/visual-review-results.md

# UX Audit スクリプト
node --check .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
node --test .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.test.mjs
# 本番パス（visual-review 存在時のみ。--skip-gh で gh 重複呼び出しを省略）
if test -f frontend/e2e/agent-review/visual-review-results.md; then
  node .cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs --skip-gh
fi

# Issue Worker dispatch
test -f .github/workflows/issue-worker-dispatch.yml

# PR Merge Worker dispatch
test -f .github/workflows/pr-merge-worker-dispatch.yml
test -f .github/workflows/pr-agent-prep.yml
test -f scripts/pr-agent-prep.sh
node --test scripts/pr-agent-prep-lib.test.mjs
gh api repos/rick-chick/agrr/rulesets --jq 'map(select(.name=="master CI required" and .enforcement=="active")) | length' | grep -q '^1$'
```

スキル参照パスが存在するか grep 不要で次を **test -f** で確認:

- `.cursor/skills/github-issue-worker/SKILL.md`
- `.cursor/skills/github-pr-merge-worker/SKILL.md`
- `.cursor/skills/ux-issue-pipeline/SKILL.md`
- `.cursor/skills/sequential-cleanup-review-workflow/SKILL.md`
- `.cursor/environment.json`
- `.cursor/scripts/cloud-gh-auth.sh`

## 2) 重大度分類

| 区分 | 定義 | 本 Automation の action |
|------|------|-------------------------|
| **P0 クリティカル** | Automation が**機能しない**（参照スキル欠落、install 失敗、dispatch workflow 破損、`collect-ux-findings` 本番パスクラッシュ、visual-review 欠落で UX Audit 不能） | **リポジトリ修正 PR** または Dashboard 手順をレポートに明記 |
| **P1 クリティカル** | 主要成果物が毀損（`gh issue list` / `githubLookupStatus: failed` が **2 週連続**、Issue Worker が再現可能バグで毎回失敗） | 根因が repo 側なら **PR**。Dashboard / Secret のみなら **レポートにエスカレーション** |
| **P1 注意（1 週のみ）** | 上記 gh 失敗が **今週のみ** | Memory に Dashboard 手順を記録。**PR 禁止** |
| **正常** | 対象なし・重複スキップ・意図した close 経路 | **何もしない** |
| **改善候補** | プロンプト改善、頻度変更、コスト削減、UX 指摘の追加起票 | **レポートに 1 行記載のみ。PR・issue 化しない** |

**禁止**: P0/P1 以外の「ついで修正」、スキル本文の書き換え、cron 変更、新 Automation 追加。

## 3) 修正（クリティカルのみ）

### PR を開いてよい変更

- 欠落・typo で Automation が SKILL を読めない（パス修正）
- `cloud-gh-auth.sh` / `environment.json` の bootstrap 失敗
- `collect-ux-findings.mjs` 等の**実行時クラッシュ**（テスト RED → TDD で最小修正）
- `.github/workflows/issue-worker-dispatch.yml` の**明らかな構文・payload 破損**
- スケジュール doc と実ファイルの**不整合で run が必ず失敗する**状態

### PR を開かない（レポートのみ）

- `AGRR_GH_PAT` 未設定 → Dashboard → Cloud Agents → Secrets 手順をレポートに記載
- Webhook secret 未注入（Cursor 既知バグ）→ Schedule 利用を推奨、secret 設定手順を記載
- Invalid trigger（6 フィールド cron）→ UI で 5 フィールドに直す手順を記載
- agent-blocked issue の**仕様・判断待ち**
- 起票 0 件（重複スコア ≥ 5）— UX Audit の設計どおり

### 修正時の TDD

ソース変更がある場合のみ [`tdd-on-edit`](../tdd-on-edit/SKILL.md)（スクリプトテストがある対象）。**スキル doc のみの修正**（パス typo）で振る舞いテストが無い場合は test-common 不要。

## 4) 監査レポート

毎 run 末尾に **Memory** と（PR がある場合）PR 本文に次を残す:

```markdown
## Cloud Automation Audit — YYYY-MM-DD

### 対象期間
直近 7 日（JST）

### Run サマリ
| Automation | 直近 run | 結果 | 備考 |
|------------|----------|------|------|
| Issue Worker | … | ok / fail / skip | … |
| UX Issue Audit | … | ok / fail / skip | … |

### スモーク
- cloud-gh-auth: pass / fail
- gh issue list: pass / fail
- visual-review-results.md: present / missing
- collect-ux-findings.test.mjs: pass / fail
- collect-ux-findings.mjs --skip-gh: pass / fail / skipped（ファイル欠落時）

### 自己監査（前回 Automation Audit）
- 前回 Memory の「実施した修正」が P0/P1 に該当していたか
- 改善候補のみで PR を開いていないか

### クリティカル所見
- （なし）または P0/P1 の箇条書き + 根拠

### 改善候補（対応しない）
- …

### 実施した修正
- （なし）または PR #N / Dashboard 手順
```

**クリティカル所見が 0 かつ修正 0** → **PR を開かず** Memory にサマリのみ書いて終了。

## 5) 禁止

- 積極的リファクタ・プロンプト改善・cron 変更
- Issue Worker / UX Audit の**業務ロジック**変更（issue 選定・起票閾値等）
- `git checkout` / `switch` / `reset` / `restore`（ユーザー明示時以外）
- 監査対象外 Automation への手を伸ばす
- 根拠なしの `gh issue create`（監査 skill は起票しない）

## 関連

- スケジュール一覧: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)
- チェックリスト: [references/AUDIT-CHECKLIST.md](references/AUDIT-CHECKLIST.md)
- Issue Worker: [`github-issue-worker`](../github-issue-worker/SKILL.md)
- UX Audit: [`ux-issue-pipeline`](../ux-issue-pipeline/SKILL.md) § Automation

---

## Automation（スケジュール）

Cloud Agent 向け。**他 Automation の実行結果を監査**し、クリティカルな repo 不具合のみ PR。

### トリガー

| cron | 意味 |
|------|------|
| `0 10 * * 5` | 毎週金曜 10:00 JST（Issue Worker 平日 run + 月曜 UX Audit の後） |

設定手順・prefill URL: [references/cursor-automation-schedule.md](references/cursor-automation-schedule.md)

### 実行フロー（Automation 専用）

1. SKILL §1 — 直近 7 日の run ログ・GitHub 副作用・スモークを収集
2. SKILL §2 — P0/P1 のみ分類（改善候補は記載のみ）
3. P0/P1 かつ repo 側根因 → SKILL §3 で最小 PR（それ以外 PR 禁止）
4. SKILL §4 形式で Memory に監査レポート

### Automation 用プロンプト（コピペ）

```
You are the AGRR Cloud Automation Audit for repository rick-chick/agrr.

Read and follow `.cursor/skills/cloud-automation-audit/SKILL.md` exactly.

Audit the last 7 days of Issue Worker and UX Issue Audit runs using GitHub side effects and repository smoke tests (you cannot read other automations' run logs or memories). Fix ONLY critical breakages in the repository. Do NOT make proactive improvements.

Open a PR only when a critical repo-side fix is required. Otherwise write the audit report to automation memory and exit without a PR.
```
