---
name: error-fix-red-green
description: Applies source changes and confirms fix by turning RED tests to GREEN. Use after investigation is complete (RED tests exist and are failing). Do not use when RED tests have not been written or confirmed. Trigger: 修正して, fix, GREEN にしたい, テストを通して, テストを直して.
disable-model-invocation: true
---

# RED/GREEN 修正スキル

調査スキルが完了した後、REDテストをGREENに修正し、修正を確認するスキル。

## When to Use

- 調査完了（REDテストが確認済み）のあと、修正を求められたとき
- エラー修正の「修正・GREEN確認」フェーズ
- Trigger: 修正して, fix, GREENにしたい, テストを通して, テストを直して

## Instructions

- REDテストが確認済みの状態でのみ使用する
- 対象に応じた修正スキルに従ってソースを修正
- `test-common`スキルを再実行しGREENになったことを確認
- For detailed steps, see [references/STEPS.md](references/STEPS.md)
- For checklists, see [references/CHECKLIST.md](references/CHECKLIST.md)

## References

- [references/STEPS.md](references/STEPS.md) - Detailed implementation steps
- [references/CHECKLIST.md](references/CHECKLIST.md) - Pre/post-fix checklists
- [error-investigation](../error-investigation/SKILL.md) - Prerequisite investigation skill
- [restart-angular](../restart-angular/SKILL.md) - Angular server restart if needed
- [restart-rails](../restart-rails/SKILL.md) - Rails server restart if needed
- [test-common](../test-common/SKILL.md) - Read before command test
