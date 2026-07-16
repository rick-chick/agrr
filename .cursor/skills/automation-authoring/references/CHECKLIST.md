# Automation Authoring — チェックリスト

## §影響 — 他オートメーション

変更前後で確認する。

- [ ] **二重起動** — 同一 issue/PR へ webhook が 2 経路から飛ばないか（[GITHUB-ACTIONS-CONSTRAINTS.md](GITHUB-ACTIONS-CONSTRAINTS.md)）
- [ ] **RETRY_BLOCK_LABELS** — 新ラベル・新状態が reconcile を塞がないか
- [ ] **Watchdog** — `detectStuckAgentReadyIssue` 等の対象外にならないか
- [ ] **pr-agent-prep** — Draft → ready 直列キューと競合しないか
- [ ] **責任空白** — Draft + CI FAIL 型（#354）のギャップを増やしていないか
- [ ] **fan-out** — 1 イベントで複数 Cloud Agent を起動しないか（1 回 1 件）
- [ ] **誤マッチ** — 依存番号は構造化パースか
- [ ] **調査と修正の分離** — 影響調査依頼中に未検証の経路変更を入れていないか

## §設計 — 着手前

- [ ] トリガー・起動条件・起動手段・終了条件・回復経路を一文ずつ書いた
- [ ] 既存同型経路を読んだ（[EXISTING-PATTERNS.md](EXISTING-PATTERNS.md)）
- [ ] `GITHUB_TOKEN` 制約を確認した
- [ ] ラベル契約が既存 Worker と矛盾しない

## §実装

- [ ] `*-dispatch-lib.mjs` に pure function + unit test
- [ ] `verify-*-dispatch-workflow` に必須スニペット追加
- [ ] retry / reconcile を設計（または「不要」の根拠を一文で）
- [ ] SKILL.md は [`skill-authoring.mdc`](../../rules/skill-authoring.mdc) 準拠（詳細は references/）

## §E2E — マージ前

1. **実データ**

```bash
# 例: 候補選定の dry-run（issue 番号・ラベルを実際の対象に合わせる）
gh issue view <N> --repo rick-chick/agrr --json number,state,labels,body
node --input-type=module -e "
  import { isDepsResolvedUnblockCandidate } from './scripts/issue-worker-dispatch-lib.mjs';
  // または追加した選定関数
"
```

2. **Actions ログ**

```bash
gh run list --repo rick-chick/agrr --workflow "<Workflow Name>" --limit 5
gh run view <RUN_ID> --repo rick-chick/agrr --log | rg 'Dispatched|Skip retry|Skipped:'
```

3. **副作用** — 次のいずれかを観測

- ラベル変化（`gh issue view`）
- Cursor Automation run 開始（Dashboard）
- 下流 PR / コメント

**unit test のみで「動く」と報告しない。**

## §登録 — マージ時

- [ ] `cursor-automation-schedule.md` に 1 行追加
- [ ] `CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md` 関連表に 1 行
- [ ] `collect-pipeline-health-lib.mjs` の `DISPATCH_WORKFLOW_NAMES`（該当時）
- [ ] `verify-skill-references.sh`（新スキル path）
- [ ] Dashboard: webhook URL / secrets / cron / プロンプト
