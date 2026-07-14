---
name: investigation-verification
description: Verifies that an investigation report is backed by tests (RED reproducible, test code exists). Use when receiving 調査完了, 原因を特定しました, investigation report, or 調査結果の報告, regardless of how obvious the cause seems.
disable-model-invocation: true
---

# 調査検証スキル

調査完了・報告を受けたときに、原因がテストで再現されているかを検証するスキル。

## When to Use

- 調査完了・原因特定報告を受けたとき
- 調査結果の妥当性を確認したいとき
- Trigger: 調査完了, 原因特定, 調査結果, 検証

## Instructions

- 原因がテストで再現できることを確認
- テストコードが存在することを検証
- 原因とテストの1:1対応をチェック
- For checklist details, see [references/CHECKLIST.md](references/CHECKLIST.md)

## References

- [references/CHECKLIST.md](references/CHECKLIST.md) - Verification checklist

## 適用時

- 「調査完了しました」「原因を特定しました」などの報告を受けたとき
- サブエージェントや他者から調査結果・原因の報告を受けたとき
- 修正に進む前に、調査完了の妥当性を確認したいとき

## 参照

| 参照 | 内容 |
|------|------|
| [error-investigation](../error-investigation/SKILL.md) | 調査手順・調査完了の定義（ステップ 5＝RED による検証） |
| [error-investigation references/CHECKLIST.md](../error-investigation/references/CHECKLIST.md) | RED を飛ばさない理由・抜け道の禁止 |
| [error-fix-red-green](../error-fix-red-green/SKILL.md) | 検証完了後に適用する修正・GREEN 確認 |
