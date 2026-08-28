# サブエージェント委譲プロンプト

親エージェントは Task ツールで起動する。`subagent_type: explore` を既定とする。`run_in_background: false`。

プロンプト内の `<REPO_ROOT>` はワークスペースルート（例: `/workspace`）に置き換える。

---

## §1 初回監査（explore）

カテゴリごとに 1 体。4 カテゴリを **並列起動**する。

### 共通テンプレート

```
<REPO_ROOT> のコードベースを、ユーザ致命的バグの観点で監査せよ。

カテゴリ: <CATEGORY>  # auth-security | data-integrity | core-availability | ux-recovery
重大度定義: .cursor/skills/critical-bug-audit-pipeline/references/severity-taxonomy.md を読んで適用

調査対象（本リポジトリ）:
- auth-security: crates/agrr-server（auth, session, backdoor, CORS）, frontend adapters/auth
- data-integrity: crates/agrr-domain, crates/agrr-adapters-*, 永続化・削除・同期 usecase
- core-availability: crates/agrr-server（起動, cable/WS, 主要 API）, frontend コアフロー
- ux-recovery: frontend guards, error handlers, 主要 usecase の error/disconnect 処理

各 finding に必ず付与:
- id: F-<category>-NN（連番）
- status: CANDIDATE（断定しない）
- severity_hypothesis: P0 | P1 | P2
- title: 短い要約
- user_impact: ユーザーが体験する被害（1〜2 文）
- evidence: [{ "path": "...", "lines": "Lx-Ly", "note": "..." }]
- repro_steps: 番号付きユーザージャーニー **または** コード因果チェーン
- suggested_issue_title: [P?][bug] ...

禁止:
- 修正コードの作成
- CONFIRMED 断定（再調査フェーズの仕事）
- 根拠のない推測

出力: Markdown（親が tmp/critical-bug-audit/raw-<category>.md に保存）
```

---

## §2 再調査（explore）

フェーズ 1 の `raw-*.md` を入力に、**初回監査とは別 subagent** で起動する。カテゴリ単位または finding バッチ（10 件以下）で並列化可。

### テンプレート

```
<REPO_ROOT> で、以下の finding 候補を再調査し CONFIRMED / REJECTED / DOWNGRADED を確定せよ。

入力:
<paste raw findings or path to tmp/critical-bug-audit/raw-<category>.md>

手順:
1. evidence の path:lines を実際に読み、主張がコードと一致するか検証
2. repro_steps が再現可能か検証（静的トレースで可）
3. 既存テストが finding を否定していないか確認
4. 本番のみの条件（env 変数・設定）があれば明記

各 finding の出力フィールド:
- id
- status: CONFIRMED | REJECTED | DOWNGRADED
- severity: P0 | P1 | P2（DOWNGRADED 時は下げる）
- status_reason: 1 文
- user_impact
- evidence: [{ path, lines, note }]
- repro_steps: 必須（CONFIRMED 時）
- acceptance_criteria: 箇条書き（観測可能）
- suggested_issue_title
- related_issues: 既知の GitHub issue 番号（gh issue list で確認）

判定基準:
- CONFIRMED: コード根拠 + repro_steps が揃う
- REJECTED: 誤検知、既修正、本番到達不能、根拠不足
- DOWNGRADED: リスクはあるが本番未使用・回避策常時あり・意図的設計

禁止:
- 修正・PR
- CONFIRMED なのに repro_steps 空

出力: JSON 配列（親が verified-findings.json にマージ）
```

### JSON 出力例（1 件）

```json
{
  "id": "F-core-availability-01",
  "category": "core-availability",
  "status": "CONFIRMED",
  "severity": "P0",
  "status_reason": "handle_socket が最初の subscribe 後に return するコードを確認",
  "title": "WebSocket は1接続1購読のみ",
  "user_impact": "農場詳細から計画最適化へ遷移すると進捗が止まる",
  "evidence": [{ "path": "crates/agrr-server/src/cable.rs", "lines": "415-516", "note": "relay 後 return" }],
  "repro_steps": ["農場詳細を開く", "計画最適化画面へ遷移", "進捗が更新されない"],
  "acceptance_criteria": ["1接続で複数購読またはチャンネル切替時に再接続", "統合テスト追加", "test-common GREEN"],
  "suggested_issue_title": "[P0][bug] WebSocket /cable は1接続1購読のみ",
  "related_issues": []
}
```
