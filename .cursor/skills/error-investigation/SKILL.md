---
name: error-investigation
description: Investigates error and bug causes from symptom to hypotheses, then verifies cause with a failing test (RED) and manages cursor TODO workflow. Use when given an error message, stack trace, reproduction steps, or when the user asks for 原因調査, バグ調査, 再現手順, debug, fix, or エラーを調べて.
disable-model-invocation: true
---

# エラー調査スキル（RED による検証まで）

エラーが与えられたとき、事象把握からREDテストによる検証まで行い、cursor TODOワークフローを管理するスキル。このスキルでは説明を求めているため、修正を行わないこと。

## When to Use

- エラーメッセージ／スタックトレース／再現手順が与えられたとき
- 原因調査を求められたとき
- Trigger: 原因調査, バグ調査, 再現手順, debug, fix, エラーを調べて

## Instructions

- 事象の把握から候補原因の絞り込みまで実施
- REDテストを作成する
- `test-common`スキルを実行し、failとなるまで絞り込む
- cursor TODOを更新して検証・修正ワークフローを管理
- For detailed steps, see [references/STEPS.md](references/STEPS.md)
- For checklists, see [references/CHECKLIST.md](references/CHECKLIST.md)

## References

- [references/STEPS.md](references/STEPS.md) - Detailed investigation steps
- [references/CHECKLIST.md](references/CHECKLIST.md) - Pre/post-investigation checklists
- [investigation-verification](../investigation-verification/SKILL.md) - Verification skill for investigation results
- [error-fix-red-green](../error-fix-red-green/SKILL.md) - Fix and green confirmation skill
- [test-common](../test-common/SKILL.md) - Read before command test