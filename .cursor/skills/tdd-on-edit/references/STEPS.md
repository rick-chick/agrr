# TDD 改修 — 各ステップの詳細

## 0. 着手前

- [`ARCHITECTURE.md`](../../../../ARCHITECTURE.md) — 触れる層の `What we require` / `Prohibited practices`
- [`evidence-before-design-and-implementation.mdc`](../../../rules/evidence-before-design-and-implementation.mdc) — 期待する振る舞いを一文で言えるか。未満なら調査継続
- [CODE_MODIFICATION_SKILLS.md](../../references/CODE_MODIFICATION_SKILLS.md) — 実装スキル・テストスキルの対応

## 1. 単位の切り方

- 1 回の RED/GREEN で扱うのは **1 つの観測可能な振る舞い**（1 Interactor 経路、1 Gateway 操作、1 コンポーネントのユーザー可視結果など）
- 大きい機能は [`feature-orchestrator`](../feature-orchestrator/SKILL.md) の Phase に従い、**Phase 内でも層ごとに本サイクルを繰り返す**

## 2. RED

1. 対象層の **テストスキル**（例: `interactor-test-server`, `gateway-test-frontend`）を開き、手順に従ってテストを書く
2. テストは **「この振る舞いが満たされれば GREEN」** になるように書く（原因の仮説だけを固定しない）
3. **`test-common`** で実行し、**失敗**を確認する
   - 既存が GREEN のまま → テストが不足しているか、期待が弱い
   - 想定外のエラー → テストの置き場・require・モックを見直す（`test/domain` は `run-test-domain-lib.sh` のみ）

## 3. GREEN

1. 対象層の **実装スキル**に従い、RED を解消する**最小限**の変更
2. **`test-common`** で当該テストが **GREEN** になることを確認
3. GREEN にならない → 実装を広げる前に、RED が正しい振る舞いを捉えているか見直す

## 4. REFACTOR（任意）

- 重複・命名・層境界の整理。**振る舞いを変えない**
- 再度 `test-common`（当該 → 必要なら全体）

## 5. 完了時

- 個別指定で GREEN → **引数なし**の `test-common`（[`rails-testing-workflow.mdc`](../../../rules/rails-testing-workflow.mdc)）
- [`test-slow-detection`](../test-slow-detection/SKILL.md)
- Clean Architecture チェックが必要なら [ワークフロー SKILL](../clean-architecture-violation-fix-workflow/SKILL.md) セクション4

## バグ修正時（本 STEPS の代わり）

[`error-investigation`](../error-investigation/SKILL.md) のステップ 5（RED による検証）と [`error-fix-red-green`](../error-fix-red-green/SKILL.md) をそのまま使う。
