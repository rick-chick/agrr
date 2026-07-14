# 原則・禁止・他スキル

## 原則

| 原則 | 意味 |
|------|------|
| **順次** | 改修 → 整理（デッド・責務外）→ レビュー → **次の修正単位**。並列改修があっても **マージ前の整理単位**は 1 つずつ本ループを完結。 |
| **セーフ削除** | 到達不能・重複カバレッジ・誤レイヤの根拠が **説明できる／再現できる** ときだけ削除。根拠ゲート: [`evidence-before-design-and-implementation.mdc`](../../../rules/evidence-before-design-and-implementation.mdc)。 |
| **移動は TDD** | 責務外コード・テストの移動は [`tdd-on-edit`](../../tdd-on-edit/SKILL.md)（移動先で RED → GREEN）。削除は移動先 GREEN のあと。 |
| **レビューは毎単位** | `ARCHITECTURE.md` 照合と `test-common` は **修正単位ごと**。「全部終わってから」にしない。 |

## やらないこと

- PR 末・Phase 末に **一括** でデッド削除・テスト整理・レビューをまとめる。
- **A〜D を 1 サブエージェント／1 ターンにまとめる**（オーケストレーション違反）。
- マニフェスト（Step 0）なしで A に入る。
- 調査サブエージェントに削除・移動まで任せる（調査と実施の混在）。
- `rg` ヒットゼロだけでセーフ削除する。
- 移動先のテストなしで責務外コードだけ削る。
- レビュー（D）を「全部終わってから」に先送りする。
- ゲート表なしの「問題なし」だけで次ステップへ進む。
- **残課題を backlog に載せず D 完了扱い**、または **外側ループを省略**して次の修正単位へ進む。
- **backlog に `pending` が残っているのに workflow 完了報告**、または **「続けますか？」で外側ループを止める**。
- D1 で「任意改善」「スコープ外」等で **ingest を省略**する（[MECHANICAL_OUTER_LOOP.md](MECHANICAL_OUTER_LOOP.md)）。

## 他スキルとの関係

| スキル | 役割 |
|--------|------|
| [`tdd-on-edit`](../../tdd-on-edit/SKILL.md) | 改修本体と移動先の RED→GREEN |
| [`dead-code-removal-workflow`](../../dead-code-removal-workflow/SKILL.md) | 広域到達可能性・削除の厳密手順 |
| [`find-method-dead-code`](../../find-method-dead-code/SKILL.md) | メソッド単位のデッド判定 |
| [`shared-screen-only-component`](../../shared-screen-only-component/SKILL.md) | UI 責務の抽出 |
| [`CODE_MODIFICATION_SKILLS.md`](../../../references/CODE_MODIFICATION_SKILLS.md) | 層別実装・テストスキルの選択 |
| [`clean-architecture-violation-fix-workflow`](../../clean-architecture-violation-fix-workflow/SKILL.md) | CA 違反修正の外側ループ（セクション0〜6）。本スキルは **修正単位の内側** の整理・レビュー |
| [`github-issue-worker`](../../github-issue-worker/SKILL.md) | 実装経路で TDD GREEN 後に本ループ **必須** |

## 参照ファイル（読み分け）

| ファイル | 読むタイミング |
|----------|----------------|
| [STARTUP.md](STARTUP.md) | 初回 tick・slug |
| [DUAL_LOOP.md](DUAL_LOOP.md) | ループ形状・L1/L2/L3・親 while |
| [MECHANICAL_OUTER_LOOP.md](MECHANICAL_OUTER_LOOP.md) | D1 ingest・禁止フレーズ・gate |
| [AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md) | Step 委譲プロンプト |
| [STEPS_ABCD.md](STEPS_ABCD.md) | A〜D 作業内容 |
| [CHECKLIST.md](CHECKLIST.md) | 進捗表・判定木 |
| [SCRIPTS.md](SCRIPTS.md) | スクリプトパス |
