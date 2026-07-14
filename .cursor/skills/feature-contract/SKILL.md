---
name: feature-contract
description: Defines API and domain behavior (ports/DTOs, request/response, errors) from requirements for parallel frontend/server work. Use with clean-architecture-goal-statement before implementation. Does not write to removed docs/contracts/.
disable-model-invocation: true
---

# Feature Contract（機能追加・振る舞い定義）

要件から API / ドメイン振る舞いを整理し、ゴール記述とテスト方針に落とし込むスキル（`docs/contracts/` は廃止）。

## When to Use

- 新機能追加時にAPI契約を定義したいとき
- フロントエンド・サーバーの並列開発を始めたいとき
- Trigger: 機能追加, API定義, 契約作成, PRD, 要件定義

## Instructions

- 要件から UseCase と API を設計（[CONTRACT_TEMPLATE](references/CONTRACT_TEMPLATE.md) を整理用に参照可）
- 出力は **clean-architecture-goal-statement** のゴール記述と、委譲プロンプトに載せる振る舞い要点（ファイル保存は必須ではない）
- 実装は他のスキルに委譲
- For detailed implementation, see references files

## References

- [references/CONTRACT_TEMPLATE.md](references/CONTRACT_TEMPLATE.md) - Contract document template
- [references/EXECUTION_FLOW.md](references/EXECUTION_FLOW.md) - Step-by-step process
- [references/EXAMPLES.md](references/EXAMPLES.md) - Contract examples and patterns
