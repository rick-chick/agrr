---
name: session-diagnosis
description: Diagnoses and fixes session-related failures in cross-origin SPA setups, particularly for public (non-auth) endpoints. Use when logged-in flow works but logged-out flow fails due to session issues (e.g. session.id nil, cookie not persisted, ActionCable rejected). Trigger: セッション問題, session issue, 非ログイン時に失敗, cross-origin cookie.
disable-model-invocation: true
---

# セッション問題の調査・修正スキル

非ログインユーザーでセッション起因の失敗が起きたとき、原因を特定し修正するスキル。

## When to Use

- ログイン時は動くが非ログイン時にセッション問題で失敗する
- `session.id` が nil になる、クッキーが保存されない
- ActionCable 接続が非ログイン時に失敗する
- Cross-origin SPA でのセッション関連エラー

## Instructions

3 フェーズで進める。各フェーズの詳細は references を参照。

### Phase 1: 調査（コード読み取りのみ）

1. 失敗フローを特定し、API/WebSocket のリクエスト順序を整理
2. session.id 依存箇所を洗い出す
3. ログイン時 vs 非ログイン時の差分を特定する

→ 詳細: [references/INVESTIGATION_FLOW.md](references/INVESTIGATION_FLOW.md)

### Phase 2: 診断（パターンマッチ）

4. 既知のパターンに照合して根本原因を特定
5. 修正方針を決定

→ 詳細: [references/SESSION_PATTERNS.md](references/SESSION_PATTERNS.md)

### Phase 3: 修正・検証

6. 修正対象に応じたスキルに従い修正
7. テスト更新・実行

→ 詳細: [references/FIX_AND_VERIFY.md](references/FIX_AND_VERIFY.md)

## References

- [references/INVESTIGATION_FLOW.md](references/INVESTIGATION_FLOW.md) - Phase 1 調査手順
- [references/SESSION_PATTERNS.md](references/SESSION_PATTERNS.md) - Phase 2 診断パターン集
- [references/FIX_AND_VERIFY.md](references/FIX_AND_VERIFY.md) - Phase 3 修正・検証手順
- [test-common](.cursor/skills/test-common/SKILL.md) - テスト実行
- [error-fix-red-green](.cursor/skills/error-fix-red-green/SKILL.md) - RED/GREEN 修正フロー
