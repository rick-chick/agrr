# 確認ゲート

各フェーズの通過条件。未達なら次フェーズに進まない。

## G1 — 初回監査完了

- [ ] スコープ内の全カテゴリで `raw-<category>.md` が存在
- [ ] 各 finding に `id`, `severity_hypothesis`, `evidence`, `repro_steps` がある
- [ ] subagent が `status: CANDIDATE` のみ（CONFIRMED 断定なし）

## G2 — 再調査完了

- [ ] `verified-findings.json` が存在
- [ ] 全 CANDIDATE が `CONFIRMED` / `REJECTED` / `DOWNGRADED` に確定
- [ ] `CONFIRMED` は `repro_steps` と `evidence` が空でない
- [ ] `CONFIRMED` は `acceptance_criteria` が観測可能

## G3 — collect 通過

- [ ] `node .cursor/skills/critical-bug-audit-pipeline/scripts/collect-critical-findings.mjs` が exit 0
- [ ] `sources.githubLookupStatus !== "failed"`
- [ ] `issue-drafts.md` が生成された

## G4 — 起票許可

- [ ] ドライラン提示済み
- [ ] ユーザーが起票を明示 **または** 依頼に「issue 化まで」が含まれる
- [ ] 起票対象は `CONFIRMED` のみ（`DOWNGRADED` は親が判断）
- [ ] `existingIssueCandidates` で OPEN かつ score ≥ 5 のものは起票しない

## 重複スコア（collect と同じ）

| 条件 | score |
|------|-------|
| タイトルに主要キーワード 2 語以上一致 | +3 |
| タイトルに主要キーワード 1 語一致 | +2 |
| 本文スニペットに finding の path 断片一致 | +2 |
| state OPEN | +2（CLOSED は +0） |

score ≥ 5 かつ OPEN → 起票スキップ（コメント追記可）。
