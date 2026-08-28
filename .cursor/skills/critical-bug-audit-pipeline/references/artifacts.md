# 成果物スキーマ

## ディレクトリ

```
tmp/critical-bug-audit/
  raw-auth-security.md
  raw-data-integrity.md
  raw-core-availability.md
  raw-ux-recovery.md
  verified-findings.json      # 正本（フェーズ 2 出力のマージ）
  issue-drafts.md             # collect スクリプト出力
  issue-registry.json         # finding_id → GitHub issue 番号
  bodies/                     # gh issue create 用本文
    F-core-availability-01.md
```

## verified-findings.json

```json
{
  "auditRunId": "<ISO8601 or uuid>",
  "repo": "rick-chick/agrr",
  "scope": ["auth-security", "data-integrity", "core-availability", "ux-recovery"],
  "sources": {
    "githubLookupStatus": "ok | skipped | failed"
  },
  "counts": {
    "total": 0,
    "confirmed": 0,
    "rejected": 0,
    "downgraded": 0,
    "likelyDuplicateOpen": 0
  },
  "findings": []
}
```

### finding オブジェクト（CONFIRMED 時必須）

| フィールド | 必須 | 説明 |
|------------|------|------|
| `id` | ✓ | `F-<category>-NN` |
| `category` | ✓ | 監査カテゴリ |
| `status` | ✓ | `CONFIRMED` / `REJECTED` / `DOWNGRADED` |
| `severity` | CONFIRMED/DOWNGRADED | `P0` / `P1` / `P2` |
| `title` | ✓ | 短い要約 |
| `user_impact` | CONFIRMED | ユーザー被害 |
| `evidence` | CONFIRMED | `{ path, lines, note }[]`、最低 1 件 |
| `repro_steps` | CONFIRMED | `string[]`、最低 1 件 |
| `acceptance_criteria` | CONFIRMED | `string[]`、最低 1 件 |
| `suggested_issue_title` | CONFIRMED | issue タイトル案 |
| `existingIssueCandidates` | - | collect が付与 `{ number, title, state, score }[]` |

## issue-registry.json

```json
{
  "auditRunId": "<same as verified-findings>",
  "created": [
    { "findingId": "F-core-availability-01", "issueNumber": 1195, "url": "https://github.com/..." }
  ],
  "skipped": [
    { "findingId": "F-data-integrity-06", "reason": "DOWNGRADED: no production callers" }
  ]
}
```
