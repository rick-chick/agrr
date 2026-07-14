---
name: tdd-on-edit
description: >-
  Test-Driven Development for code changes: write or adjust a failing test (RED),
  confirm with test-common, implement minimally (GREEN), then refactor.
  Use for any source or test edit (改修, 実装, リファクタ, 機能追加の各層).
  For bugs use error-investigation then error-fix-red-green instead of duplicating RED here.
disable-model-invocation: false
---

# 改修 TDD（RED → GREEN → REFACTOR）

ソース・テストの追加・変更では、**観測可能な振る舞いを表明するテスト**を先に書き、`test-common` で **RED** を確認してから本実装する。

## When to Use

- バグ以外の改修・新規実装（Interactor / Gateway / Presenter / Controller / Angular 各層など）
- Trigger: 改修, 実装, 追加, リファクタ, TDD, RED, GREEN, テストから書く

**バグ・エラー**は本スキルの代わりに [`error-investigation`](../error-investigation/SKILL.md) → [`error-fix-red-green`](../error-fix-red-green/SKILL.md) を使う（RED/GREEN の責務が分離済み）。

## Instructions

1. **対象層のテストスキル**を [CODE_MODIFICATION_SKILLS.md](../../references/CODE_MODIFICATION_SKILLS.md) から選び、振る舞いを 1 単位に切る。
2. **RED**: テストを追加・更新し、`test-common` で**意図した理由で失敗**することを確認する。
3. **GREEN**: 対象層の**実装スキル**に従い最小限の変更。`test-common` で当該テストが GREEN になることを確認する。
4. **REFACTOR**（任意）: 振る舞いを変えず整理。再度 `test-common`（個別 → 全体は [`rails-testing-workflow.mdc`](../../rules/rails-testing-workflow.mdc)）。
5. 完了後 [`test-slow-detection`](../test-slow-detection/SKILL.md) を実施する。

詳細手順・チェックリスト: [references/STEPS.md](references/STEPS.md)、[references/CHECKLIST.md](references/CHECKLIST.md)。

## 他スキルとの関係

| スキル | 役割 |
|--------|------|
| [`test-common`](../test-common/SKILL.md) | テスト実行の唯一の経路 |
| [`rails-testing-workflow.mdc`](../../rules/rails-testing-workflow.mdc) | 個別 GREEN 後の全体実行・`test/domain` の require |
| [`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc) | RED を書く前に「何が正しい振る舞いか」を説明できる／再現できる |
| [`feature-orchestrator`](../feature-orchestrator/SKILL.md) | 機能一式の Phase 束ね。各 Phase 内の層実装は本 TDD サイクル |
| [`process-monitor`](../process-monitor/SKILL.md) | シェル完了まで成功・失敗を断定しない |

## References

- [references/STEPS.md](references/STEPS.md)
- [references/CHECKLIST.md](references/CHECKLIST.md)
- [`.cursor/rules/tdd-on-edit.mdc`](../../rules/tdd-on-edit.mdc)
