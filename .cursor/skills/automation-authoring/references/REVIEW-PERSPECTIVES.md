# Automation Authoring — レビュー観点（正本）

独立レビュー（サブエージェント委譲・人間レビュー・自己レビュー）で共通に使う観点表。実装担当 Agent は本ファイルをレビュー依頼の入力に含める。

**判断の即決**: [JUDGMENT-CRITERIA.md](JUDGMENT-CRITERIA.md)  
**設計背景**: [PRINCIPLES.md](PRINCIPLES.md)  
**手順・フェーズ**: [../SKILL.md](../SKILL.md) §3〜§5

---

## 1. レビュー観点（必須 8 軸）

各軸で **Pass / Fail / N/A** を付け、Fail には根拠（ファイルパス・行・スキル節）を必須とする。

| # | 観点 | 見ること | 参照ドキュメント |
|---|------|----------|------------------|
| A | **完遂・回復** | 滞留時に reconcile / retry が人間再開なしで再開するか。責任空白（どの Worker も動かない組み合わせ）を増やしていないか | [PRINCIPLES.md §目的・§全部拾う](PRINCIPLES.md)、[CHECKLIST.md §影響](CHECKLIST.md)、[delivery-agent/SKILL.md §0](../../delivery-agent/SKILL.md) |
| B | **二層分離** | 機械が merge / close / obsolete / 経路を決めていないか。判断は Agent の `gh` 観測に委ねているか | [JUDGMENT-CRITERIA.md §1・§3](JUDGMENT-CRITERIA.md)、[PRINCIPLES.md §二層分離](PRINCIPLES.md) |
| C | **機械ゲート入力** | ゲートが GitHub API 構造フィールドのみか。本文・コメントパースがないか | [automation-philosophy-priority.mdc §本文パース禁止](../../rules/automation-philosophy-priority.mdc)、[JUDGMENT-CRITERIA.md §3](JUDGMENT-CRITERIA.md) |
| D | **全部拾う** | 「Draft だけ」「ラベルありだけ」等の狭い場合分けで本筋候補を落としていないか。救済だけに押し付けていないか | [PRINCIPLES.md §全部拾う](PRINCIPLES.md)、[PRINCIPLES.md §本筋と救済](PRINCIPLES.md) |
| E | **コスト・効率** | 起動コスト・効率化を理由に dispatch / reconcile を省略していないか | [automation-philosophy-priority.mdc §エージェント起動 vs 機械省略](../../rules/automation-philosophy-priority.mdc)、[JUDGMENT-CRITERIA.md §5 No-Go](JUDGMENT-CRITERIA.md) |
| F | **primary / retry 整合** | ゲートロジックが `*-dispatch-lib.mjs` に一箇所か。primary と reconcile が同じ pure function を共有しているか | [SKILL.md §3](../SKILL.md)、[EXISTING-PATTERNS.md](EXISTING-PATTERNS.md) |
| G | **回帰テスト** | 以前止まっていた形（責任空白）を unit で固定しているか。workflow 契約テストがあるか | [PRINCIPLES.md §責任空白の回帰テスト](PRINCIPLES.md)、[CHECKLIST.md §実装](CHECKLIST.md) |
| H | **下流整合** | SKILL・`pr-agent-prep`・watchdog・Delivery payload と矛盾しないか。二重起動・fan-out がないか | [CHECKLIST.md §影響](CHECKLIST.md)、[CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md](../../../../docs/automation/CURSOR-AUTOMATION-AND-GITHUB-WORKFLOWS.md)、[github-pr-merge-worker/SKILL.md](../../github-pr-merge-worker/SKILL.md) |

### 観点別の典型 Fail 例

| 観点 | Fail 例 |
|------|---------|
| A | CI green + Draft で primary / reconcile 両方 skip → Agent に webhook が届かない |
| B | dispatch lib が「obsolete」と判定して webhook を送らない |
| C | workflow bash で `Closes #N` を regex パースしてゲートする |
| D | `isDraft` のみで未リンク PR まで一律 skip（prep 待ちと未リンク救済を混同） |
| E | 「Agent 起動が多い」だけを理由に `ci_completed` で Draft を常に skip |
| F | `classifyPrimary*` と `classifyReconcile*` で別ロジックの `isDraft` 判定 |
| G | 未リンク Draft + CI green のテストがない |
| H | SKILL は「未リンク Draft は Agent が ready」と書くが dispatch が起動しない |

---

## 2. レビュー対象ファイル（変更種別ごと）

| 変更種別 | 最低限読むファイル |
|----------|-------------------|
| issue dispatch | `issue-worker-dispatch-lib.mjs`、対応 workflow、`verify-issue-worker-dispatch-workflow-lib.mjs` |
| PR merge dispatch | `pr-merge-worker-primary-dispatch-lib.mjs`、`pr-merge-worker-retry-dispatch-lib.mjs`、`delivery-dispatch-lib.mjs`、対応 workflow |
| pr-agent-prep | `pr-agent-prep-lib.mjs`、`pr-agent-prep.sh`、`pr-agent-prep.yml` |
| Agent 手順 | `delivery-agent/SKILL.md`、該当 Worker SKILL |
| 新規パイプライン | 上記 + [EXISTING-PATTERNS.md](EXISTING-PATTERNS.md) の同型 |

---

## 3. 独立レビュー用プロンプト（サブエージェント委譲）

実装担当 Agent は **Phase 3** で次をそのまま（または差分を追記して）サブエージェントに渡す。`subagent_type: generalPurpose`、実装担当とは **別 run**（同一会話内の Task 委譲可）。

```markdown
あなたは AGRR オートメーションの独立レビュアーです。実装担当とは別視点でレビューし、コード変更は行わない。

## コンテキスト
- リポジトリ: rick-chick/agrr（パス: <REPO_ROOT>）
- 変更目的: <1文>
- 変更ファイル: <リスト>
- 着手前 5 項目（実装担当が記載）:
  1. トリガー: …
  2. 起動条件: …
  3. 起動手段: …
  4. 終了条件: …
  5. 回復経路: …

## 必読（観点の正本）
- .cursor/skills/automation-authoring/references/REVIEW-PERSPECTIVES.md
- .cursor/skills/automation-authoring/references/JUDGMENT-CRITERIA.md
- .cursor/skills/automation-authoring/references/PRINCIPLES.md

## タスク
1. 変更 diff と上記ドキュメントを突き合わせ、REVIEW-PERSPECTIVES §1 の観点 A〜H ごとに Pass/Fail/N/A を判定する。
2. Fail にはファイルパス・該当ロジック・違反するスキル節を引用する。
3. 責任空白（どの経路でも webhook が届かない状態）の有無を列挙する。
4. 修正は最小スコープで優先順位付き（P0 思想違反 / P1 回帰テスト不足 / P2 ドキュメントのみ）。
5. unit test のみで「完了」と言えるか否かを明示する。

## 出力形式（日本語）
### サマリ（1〜3 文）
### 観点判定表（A〜H）
### 責任空白
### 修正推奨（優先順）
### マージ Go / No-Go
```

---

## 4. 修正ループ（Phase 4）

| ラウンド | 実施者 | 内容 |
|----------|--------|------|
| R0 | 実装担当 | Phase 2 完了（unit RED→GREEN、workflow 契約テスト） |
| R1 | **独立レビュアー** | §3 プロンプトでサブエージェント委譲。No-Go なら R2 へ |
| R2 | 実装担当 | Fail 項目のみ修正。思想違反（P0）は同一 PR で解消 |
| R3 | 実装担当 | `node --test` 再実行。変更がゲートに触れたら回帰テスト追加 |
| R4 | **独立レビュアー** | 差分のみ再委譲（全文レビュー不要）。P0/P1 が残れば R2 |
| 完了 | 実装担当 | レビュアーが **マージ Go**、かつ Phase 5 E2E 完了 |

**打ち切り条件**

- P0（思想違反・責任空白）が残る → E2E に進まない
- 同一観点で 3 ラウンド Fail が解消しない → 設計を Phase 1 に戻す（場合分けの見直し）
- レビュアーと実装担当が同一 Agent のみの run → **サブエージェント委譲を省略してはならない**

**人間レビュー**: 本リポジトリのオートメーション本筋では必須ではない。サブエージェント独立レビューが機械的ゲートに相当する。

---

## 5. マージ Go / No-Go（レビュアー判定）

| 判定 | 条件 |
|------|------|
| **Go** | 観点 A〜H で P0/P1 の Fail なし。責任空白なし。E2E 手順が [CHECKLIST.md §E2E](CHECKLIST.md) に沿って実施可能 |
| **No-Go** | P0 Fail 1 つ以上、または責任空白が残る、または primary/reconcile のゲート不整合 |
| **Conditional Go** | P2（ドキュメント・コメント）のみ。E2E 前に SKILL / schedule 更新を Phase 6 で完了すること |
