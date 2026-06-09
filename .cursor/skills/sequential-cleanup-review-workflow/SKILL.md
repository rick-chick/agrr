---
name: sequential-cleanup-review-workflow
description: >-
  After each modification unit, removes dead code, moves or safe-deletes out-of-layer
  tests and component code, then reviews before the next unit—not batched at PR end.
  Use when the user asks for 順次改修後の整理, 責務外テストの移動, セーフ削除,
  コンポーネント責務外の移動, 改修後レビュー, or names this skill during feature/refactor work.
disable-model-invocation: true
---

# 順次クリーンアップ・レビュー（AGRR）

## 適用

- **修正単位**（1 イテレーションで完結する改修の束）ごとに、本スキルのループを **1 回** 回す。
- 機能一式の Phase 内・CA 違反修正の内側ループ・単発改修のいずれでも、**後片付けを PR 末にまとめない**。
- 自動起動はしない（`disable-model-invocation: true`）。ユーザーがスキル名を明示したとき、または上記トリガ語で依頼されたときに従う。

## 原則

| 原則 | 意味 |
|------|------|
| **順次** | 改修 → 整理（デッド・責務外）→ レビュー → **次の修正単位** の順。並列改修があっても、**マージ前の整理単位**は 1 つずつ本ループを完結させる。 |
| **セーフ削除** | 到達不能・重複カバレッジ・誤レイヤの根拠が **説明できる／再現できる** ときだけ削除。根拠ゲートは [`evidence-before-design-and-implementation.mdc`](../../rules/evidence-before-design-and-implementation.mdc)。 |
| **移動は TDD** | 責務外コード・テストの移動は [`tdd-on-edit`](../tdd-on-edit/SKILL.md)（移動先で RED → GREEN）。削除は移動先 GREEN のあと。 |
| **レビューは毎単位** | `ARCHITECTURE.md` 照合と `test-common` は **修正単位ごと**。「全部終わってから」にしない。 |

## 修正単位ごとのループ

```
改修（RED→GREEN 済み）
  → A デッドコード
  → B 責務外テスト（移動 or セーフ削除）
  → C 責務外コード（移動 or セーフ削除）
  → D レビュー
  → 次の修正単位
```

チェックリスト・判定木: [references/CHECKLIST.md](references/CHECKLIST.md)

## スクリプト

**スキル用スクリプトは本スキル配下の [`scripts/`](scripts/) に置く。** リポジトリ直下 `scripts/` には追加しない（[`REFERENCES_GUIDE`](../_common/REFERENCES_GUIDE.md)）。

本ワークフローで呼ぶ他スキルのスクリプトも、各スキル配下のパスを使う:

| 用途 | パス |
|------|------|
| R4 契約テスト（全体） | `scripts/run-rust-contract-tests.sh`（リポジトリ共有） |
| agrr-domain | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| Frontend | `.cursor/skills/test-common/scripts/run-test-frontend.sh` |
| メソッド単位デッド候補 | `.cursor/skills/find-method-dead-code/scripts/find-method-dead-code.py` |

実行手順の正は各スキルの SKILL.md（[`test-common`](../test-common/SKILL.md) 等）。

### A — デッドコード削除（触れた範囲）

1. **スコープ**: 当該修正単位で変更したファイルと、その import / 呼び出し先に限定して広げる（リポジトリ全体の網羅は [`dead-code-removal-workflow`](../dead-code-removal-workflow/SKILL.md) に委譲）。
2. **ファイル・モジュール**: 到達不能が確定したもののみ削除（Phase A〜C は dead-code-removal-workflow に準拠）。
3. **メソッド単位**: 候補があれば [`find-method-dead-code`](../find-method-dead-code/SKILL.md) で個別判定してから削除。
4. **npm 依存**: フロントでパッケージを削ったら `frontend` で `npm install` し lock を更新。

### B — 責務外テストの移動またはセーフ削除

**責務の正**: 層ごとのテストスキル（[`CODE_MODIFICATION_SKILLS.md`](../../references/CODE_MODIFICATION_SKILLS.md) のテスト列）と `ARCHITECTURE.md` の層定義。

| 観測 | 扱い |
|------|------|
| 誤レイヤ（例: Component spec が UseCase 分岐を網羅） | **移動** — 正しい `*.spec.ts` / `test/` に振る舞いを移し、元はセーフ削除 |
| 重複（同一振る舞いを複数ファイルで検証） | **統合** — 不足シナリオを残す側へ移してからセーフ削除 |
| 存在検査のみ・実装詳細の固定 | **削除 or 振る舞いへ書き換え**（正しい層で） |
| 正しい層だが obsolete（削除した API / 画面） | **セーフ削除**（到達不能とセットで根拠を残す） |

移動・削除のあと **移動先・残存テスト** を `test-common` で個別 GREEN。

### C — コンポーネント（および触れた層）の責務外コード

| 観測 | 扱い |
|------|------|
| Component にユースケース分岐・Gateway 直呼び | **UseCase / Presenter へ移動**（実装スキルは CODE_MODIFICATION_SKILLS） |
| 画面完結 UI（開閉・ホバー・タイマー）が Feature に混在 | [`shared-screen-only-component`](../shared-screen-only-component/SKILL.md) で shared へ抽出 |
| Presenter / Gateway / Interactor の層越境 | 正しい層へ移動。edge の配線だけ Controller / CompositionRoot 側で更新 |
| 移動後に呼ばれなくなった旧コード | A（デッドコード）に回してセーフ削除 |

**Component 以外**（Presenter・Gateway・Interactor 等）も同様に、触れたファイル内の責務外を同ループで処理する。

### D — レビュー（修正単位ごと・必須）

1. **ARCHITECTURE**: 触れた層の `## What we require` と `## Prohibited practices` を照合し、層名・条項・問題の有無を短文で記録（[`ARCHITECTURE.md`](../../../ARCHITECTURE.md)）。
2. **テスト**: [`test-common`](../test-common/SKILL.md) — `.cursor/skills/test-common/scripts/` 経由。当該ファイル指定で GREEN → 契約は `scripts/run-rust-contract-tests.sh` で全体（[`rails-testing-workflow.mdc`](../../rules/rails-testing-workflow.mdc)）。
3. **遅延**: [`test-slow-detection`](../test-slow-detection/SKILL.md)。
4. **コミット**: ユーザー依頼時のみ。無関係変更は [`dead-code-removal-workflow`](../dead-code-removal-workflow/SKILL.md) Phase F と同様にパス限定 `git add`。

**D が完了するまで次の修正単位に進まない。**

## 他スキルとの関係

| スキル | 役割 |
|--------|------|
| [`tdd-on-edit`](../tdd-on-edit/SKILL.md) | 改修本体と移動先の RED→GREEN |
| [`dead-code-removal-workflow`](../dead-code-removal-workflow/SKILL.md) | 広域到達可能性・削除の厳密手順 |
| [`find-method-dead-code`](../find-method-dead-code/SKILL.md) | メソッド単位のデッド判定 |
| [`shared-screen-only-component`](../shared-screen-only-component/SKILL.md) | UI 責務の抽出 |
| [`CODE_MODIFICATION_SKILLS.md`](../../references/CODE_MODIFICATION_SKILLS.md) | 層別実装・テストスキルの選択 |
| [`clean-architecture-violation-fix-workflow`](../clean-architecture-violation-fix-workflow/SKILL.md) | CA 違反修正の外側ループ（セクション0〜6）。本スキルは **修正単位の内側** の整理・レビュー |

## やらないこと

- PR 末・Phase 末に **一括** でデッド削除・テスト整理・レビューをまとめる。
- `rg` ヒットゼロだけでセーフ削除する。
- 移動先のテストなしで責務外コードだけ削る。
- レビュー（D）を「全部終わったら」に先送りする。

## References

- [references/CHECKLIST.md](references/CHECKLIST.md) — 修正単位の進捗表・テスト/コードの判定木・レビュー記録テンプレ
