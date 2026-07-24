# Automation Authoring — チェックリスト

## §影響 — 他オートメーション

変更前後で確認する。

- [ ] **二重起動** — 同一 issue/PR へ webhook が 2 経路から飛ばないか（[GITHUB-ACTIONS-CONSTRAINTS.md](GITHUB-ACTIONS-CONSTRAINTS.md)）
- [ ] **RETRY_BLOCK_LABELS** — 新ラベル・新状態が reconcile を塞がないか
- [ ] **Watchdog** — `detectStuckAgentReadyIssue` 等の対象外にならないか
- [ ] **pr-agent-prep** — Draft → ready 直列キューと競合しないか。`agent-merge` は `closingIssuesReferences` 必須であることと矛盾しないか
- [ ] **責任空白** — どの Worker も動かず人間再開待ちになるギャップを増やしていないか（正本: [PRINCIPLES.md §目的](PRINCIPLES.md)）
- [ ] **人間レビューゲート** — 「レビュー／承認がないと不十分」を理由にオプトインや人間待ちを足していないか（[PRINCIPLES.md §このリポジトリ固有](PRINCIPLES.md)）
- [ ] **場合分けの過剰** — 「この場合だけ起動」を増やして止まる組み合わせを作っていないか（[PRINCIPLES.md §全部拾う](PRINCIPLES.md)）。狭い例外より対象を広げた方がよいか
- [ ] **オプトイン前提** — 追加ラベルや特定ブランチ名を「動かない理由」にしていないか（既定は対象・除外はオプトアウト）
- [ ] **fan-out** — 1 イベントで複数 Cloud Agent を起動しないか（1 回 1 件）
- [ ] **調査と修正の分離** — 影響調査依頼中に未検証の経路変更を入れていないか

## §設計 — 着手前

- [ ] トリガー・起動条件・起動手段・終了条件・回復経路を一文ずつ書いた
- [ ] 回復経路が **人間の UI 再開・ラベル手付けを前提にしていない**
- [ ] 既存同型経路を読んだ（[EXISTING-PATTERNS.md](EXISTING-PATTERNS.md)）
- [ ] `GITHUB_TOKEN` 制約を確認した
- [ ] ラベル契約が既存 Worker と矛盾しない
- [ ] [PRINCIPLES.md §目的](PRINCIPLES.md)（人間介在なし完遂）に沿う

## §実装

- [ ] `*-dispatch-lib.mjs` に pure function + unit test
- [ ] `verify-*-dispatch-workflow` に必須スニペット追加
- [ ] retry / reconcile を設計（または「不要」の根拠を一文で）
- [ ] SKILL.md は [`skill-authoring.mdc`](../../rules/skill-authoring.mdc) 準拠（詳細は references/）

## §独立レビュー — Phase 3〜4（省略禁止）

正本: [REVIEW-PERSPECTIVES.md](REVIEW-PERSPECTIVES.md)。手順: [SKILL.md §Phase 3〜4](../SKILL.md)。

- [ ] Phase 0 の 5 項目をレビュー依頼文に含めた
- [ ] **サブエージェント委譲**（`generalPurpose`）で実装担当と別視点のレビューを実施した
- [ ] 観点 [A〜H](REVIEW-PERSPECTIVES.md) ごとに Pass/Fail/N/A を記録した
- [ ] 責任空白（webhook がどの経路でも届かない組み合わせ）を列挙し、増やしていない
- [ ] P0/P1 Fail を修正し、差分のみ再委譲して **マージ Go** を得た
- [ ] unit GREEN のみで「完了」と報告していない（E2E は §E2E で実施）

## §E2E — マージ前

1. **実データ**

```bash
# 例: 候補選定の dry-run（issue 番号・ラベルを実際の対象に合わせる）
gh issue view <N> --repo rick-chick/agrr --json number,state,labels,body
node --input-type=module -e "
  import { selectReconcileDispatchCandidate } from './scripts/issue-worker-dispatch-lib.mjs';
  // または collectReconcileDispatchCandidates 等の選定関数
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
- [ ] `.cursor/skills/automation-pipeline-watchdog/scripts/collect-pipeline-health-lib.mjs` の `DISPATCH_WORKFLOW_NAMES`（該当時）
- [ ] `verify-skill-references.sh`（新スキル path）
- [ ] Dashboard: webhook URL / secrets / cron / プロンプト
