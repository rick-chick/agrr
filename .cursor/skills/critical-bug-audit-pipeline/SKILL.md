---
name: critical-bug-audit-pipeline
description: >-
  ユーザ致命的バグの観点でコードベースを監査し、サブエージェントで再調査・確認後に GitHub Issue を起票する。
  致命的バグレビュー、セキュリティ監査から issue 化、データ整合性リスク洗い出し、
  再現性重視のバグバックログ作成で適用する。実装は github-issue-worker に委譲。
---

# ユーザ致命的バグ監査 → Issue 起票

一般化した重大度基準でリスクを列挙し、**サブエージェント再調査で CONFIRMED のみ** issue 化する。

```
基準読込 → カテゴリ別初回監査（並列 subagent）
  → verified-findings.json 草案
  → カテゴリ別再調査（並列 subagent）
  → collect-critical-findings.mjs（検証・重複照合）
  → ドライラン → gh issue create → agent-ready
```

正本: [references/severity-taxonomy.md](references/severity-taxonomy.md)（重大度定義）

## いつ使うか

- 「ユーザ致命的バグの観点でレビューして issue 化して」
- セキュリティ・データ整合性・コア機能停止の横断監査からバックログ化
- 再現手順とコード根拠を揃えた bug issue 一括起票

## 適用範囲

| 経路 | スキル |
|------|--------|
| 本パイプライン（監査〜起票） | **本スキル** |
| 単発 issue 起票 | **`github-issue-creator`** |
| UX 監査由来 | **`ux-issue-pipeline`** / **`ux-issue-creator`** |
| 起票後の実装 | **`github-issue-worker`** |

## 0) 着手前

1. [`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc) — 根拠ゲート
2. `mkdir -p tmp/critical-bug-audit`
3. [references/severity-taxonomy.md](references/severity-taxonomy.md) を読み、判定軸を固定する
4. 監査スコープを決める（未指定なら **全カテゴリ**）:
   - `auth-security` — 認証・認可・秘密情報
   - `data-integrity` — 保存・削除・トランザクション・同期
   - `core-availability` — コア機能利用不能・リアルタイム・起動
   - `ux-recovery` — エラー回復・誤状態表示

---

## フェーズ 1 — カテゴリ別初回監査（並列 subagent）

親エージェントは **Task `explore`** をカテゴリごとに **並列起動**する（`run_in_background: false`）。

プロンプト: [references/subagent-prompts.md](references/subagent-prompts.md) §1

各 subagent の出力を `tmp/critical-bug-audit/raw-<category>.md` に保存する。

**必須**: 各 finding に `id`（`F-<category>-NN`）、`severity_hypothesis`（P0/P1/P2）、`user_impact`、`evidence`（`path:Lx-Ly`）、`repro_steps`（ユーザージャーニーまたは静的トレース）を含める。

初回監査だけでは **CONFIRMED と断定しない**（`status: CANDIDATE`）。

---

## フェーズ 2 — 再調査（並列 subagent）

フェーズ 1 の候補を入力に、**同カテゴリまたは関連カテゴリ**で Task `explore` を再起動する。

プロンプト: [references/subagent-prompts.md](references/subagent-prompts.md) §2

各 finding の `status` を次のいずれかに確定する:

| status | 意味 | issue 化 |
|--------|------|----------|
| `CONFIRMED` | コード根拠 + 再現手順が揃った | 可 |
| `REJECTED` | 根拠不十分・誤検知・既修正 | 不可 |
| `DOWNGRADED` | リスクはあるが本番影響が限定的 | 任意（P を下げて起票可） |

**CONFIRMED の必須フィールド**（[references/artifacts.md](references/artifacts.md)）:

- `repro_steps` — ユーザー操作手順 **または** コード上の因果チェーン（どちらか一方で可。両方あるとよい）
- `evidence` — `path` + 行番号
- `severity` — P0 / P1 / P2
- `acceptance_criteria` — 観測可能な完了条件

再調査結果を `tmp/critical-bug-audit/verified-findings.json` にマージする。

---

## フェーズ 3 — 機械検証・重複照合

```bash
node .cursor/skills/critical-bug-audit-pipeline/scripts/collect-critical-findings.mjs
```

- JSON スキーマ検証（必須フィールド・`CONFIRMED` の repro ゲート）
- `gh issue list --search` による重複候補付与
- 出力: `tmp/critical-bug-audit/issue-drafts.md`

`sources.githubLookupStatus` が **`failed`** のときは **起票禁止**（[`github-issue-creator`](../github-issue-creator/SKILL.md) と同様）。

---

## フェーズ 4 — ドライラン（必須）

`gh issue create` の**前**にチャットまたは `issue-drafts.md` へ出力する:

- 起票予定一覧（#候補タイトル・優先度・カテゴリ）
- スキップ一覧（`REJECTED` / 重複 OPEN score ≥ 5 / repro 不足）
- 各 issue の `agent-ready` 付与予定

**ユーザーが「起票して」と明示するまで `gh issue create` しない。**

例外: 依頼文に「確認後 issue 化」「起票まで」が含まれる場合は、フェーズ 2 で CONFIRMED かつフェーズ 3 exit 0 なら §5 へ進んでよい。

---

## フェーズ 5 — Issue 起票

[`github-issue-creator`](../github-issue-creator/SKILL.md) の本文テンプレートに従う。

```bash
gh issue create --repo rick-chick/agrr \
  --title "[P0][bug] <要約>" \
  --label bug \
  --label agent-ready \
  --body-file tmp/critical-bug-audit/bodies/<finding-id>.md
```

- **1 finding = 1 issue**（統合は同一根因・同一修正単位のみ。§2 で親が判断）
- バグは `--label bug`
- 実装対象は起票時に `agent-ready` を付与
- 調査のみ・再現不能は `agent-ready` 不可

起票後、`tmp/critical-bug-audit/issue-registry.json` に `finding_id → issue_number` を記録する。

---

## フェーズ 6 — 実装（別実行）

本パイプラインのスコープ外。`github-issue-worker` が `agent-ready` issue を実装する。

---

## サブエージェント運用規律

| 規則 | 内容 |
|------|------|
| 並列化 | フェーズ 1・2 はカテゴリ単位で **同時起動**（最大 4） |
| 役割分離 | 初回監査と再調査は **別 subagent**（同プロンプトの使い回し禁止） |
| 再現性 | subagent 出力は必ず `tmp/critical-bug-audit/` に保存 |
| 断定 | 親エージェントは subagent の `CONFIRMED` を鵜呑みにせず、フェーズ 3 で検証 |
| 実装禁止 | subagent に修正・PR 作成をさせない |

---

## 部分実行の早見

| 依頼 | フェーズ |
|------|----------|
| 「致命的バグ観点でレビューだけ」 | 0 → 1 → 2（起票なし） |
| 「レビューして issue 化」 | 0 → 1 → 2 → 3 → 4 → 5 |
| 「#N を実装」 | 6 のみ（`github-issue-worker`） |

## 禁止

- `CONFIRMED` なのに `repro_steps` または `evidence` が空の issue 起票
- フェーズ 2 を省略した起票
- 重複確認なしの大量 `gh issue create`
- 本パイプライン内での PR 作成・修正実装
- `githubLookupStatus: failed` のまま起票
- 完了条件への本番確認記載（[`github-issue-creator`](../github-issue-creator/SKILL.md) §8）

## 関連

- 重大度定義: [references/severity-taxonomy.md](references/severity-taxonomy.md)
- subagent プロンプト: [references/subagent-prompts.md](references/subagent-prompts.md)
- 成果物スキーマ: [references/artifacts.md](references/artifacts.md)
- 確認ゲート: [references/gates.md](references/gates.md)
- 単発起票: **`github-issue-creator`**
- バグ修正 TDD: **`error-investigation`** → **`error-fix-red-green`**
