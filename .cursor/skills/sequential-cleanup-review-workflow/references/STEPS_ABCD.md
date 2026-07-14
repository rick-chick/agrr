# 内側ステップ A〜D

内側 1 周の流れ（shell + agent 委譲の詳細は [DUAL_LOOP.md](DUAL_LOOP.md)）:

```text
改修（RED→GREEN 済み）
  → 0 マニフェスト（スコープ確定）
  → A デッドコード
  → B 責務外テスト（移動 or セーフ削除）
  → C 責務外コード（移動 or セーフ削除）
  → D レビュー（D1 候補を **すべて** TSV → ingest。AI 取捨選択禁止）
  → 外側 gate exit 0 まで handoff 連鎖
```

**エージェント実行時**は親を **オーケストレーター** とし、A〜D を自分でまとめて実装しない。Step 0 と各ステップを **直列**でサブエージェントに委譲する（[`use-skills-on-edit`](../../../rules/use-skills-on-edit.mdc) の並列委譲は本ループには適用しない）。手順・プロンプト・ゲート: [AGENT_ORCHESTRATION.md](AGENT_ORCHESTRATION.md)。

チェックリスト・判定木: [CHECKLIST.md](CHECKLIST.md)

## A — デッドコード削除（触れた範囲）

1. **スコープ**: 当該修正単位で変更したファイルと、その import / 呼び出し先に限定（リポジトリ全体は [`dead-code-removal-workflow`](../../dead-code-removal-workflow/SKILL.md) に委譲）。
2. **ファイル・モジュール**: 到達不能が確定したもののみ削除（Phase A〜C は dead-code-removal-workflow に準拠）。
3. **メソッド単位**: 候補があれば [`find-method-dead-code`](../../find-method-dead-code/SKILL.md) で個別判定してから削除。
4. **npm 依存**: フロントでパッケージを削ったら `frontend` で `npm install` し lock を更新。

## B — 責務外テストの移動またはセーフ削除

**責務の正**: 層ごとのテストスキル（[`CODE_MODIFICATION_SKILLS.md`](../../../references/CODE_MODIFICATION_SKILLS.md) のテスト列）と `ARCHITECTURE.md` の層定義。

| 観測 | 扱い |
|------|------|
| 誤レイヤ（例: Component spec が UseCase 分岐を網羅） | **移動** — 正しい `*.spec.ts` / `test/` に振る舞いを移し、元はセーフ削除 |
| 重複（同一振る舞いを複数ファイルで検証） | **統合** — 不足シナリオを残す側へ移してからセーフ削除 |
| 存在検査のみ・実装詳細の固定 | **削除 or 振る舞いへ書き換え**（正しい層で） |
| 正しい層だが obsolete（削除した API / 画面） | **セーフ削除**（到達不能とセットで根拠を残す） |

移動・削除のあと **移動先・残存テスト** を `test-common` で個別 GREEN。

## C — コンポーネント（および触れた層）の責務外コード

| 観測 | 扱い |
|------|------|
| Component にユースケース分岐・Gateway 直呼び | **UseCase / Presenter へ移動**（実装スキルは CODE_MODIFICATION_SKILLS） |
| 画面完結 UI（開閉・ホバー・タイマー）が Feature に混在 | [`shared-screen-only-component`](../../shared-screen-only-component/SKILL.md) で shared へ抽出 |
| Presenter / Gateway / Interactor の層越境 | 正しい層へ移動。edge の配線だけ Controller / CompositionRoot 側で更新 |
| 移動後に呼ばれなくなった旧コード | A（デッドコード）に回してセーフ削除 |

**Component 以外**（Presenter・Gateway・Interactor 等）も同様に、触れたファイル内の責務外を同ループで処理する。

## D — レビュー（修正単位ごと・必須）

1. **ARCHITECTURE**: 触れた層の `## What we require` と `## Prohibited practices` を照合し、層名・条項・問題の有無を短文で記録（[`ARCHITECTURE.md`](../../../../ARCHITECTURE.md)）。
2. **テスト**: [`test-common`](../../test-common/SKILL.md) — `.cursor/skills/test-common/scripts/` 経由。当該ファイル指定で GREEN → 契約は `scripts/run-rust-contract-tests.sh` で全体（[`rails-testing-workflow.mdc`](../../../rules/rails-testing-workflow.mdc)）。
3. **遅延**: [`test-slow-detection`](../../test-slow-detection/SKILL.md)。
4. **コミット**: ユーザー依頼時のみ。無関係変更は [`dead-code-removal-workflow`](../../dead-code-removal-workflow/SKILL.md) Phase F と同様にパス限定 `git add`。

**D が完了するまで次の修正単位に進まない。** 残課題が backlog に残っている間は **外側ループ** を継続し、PR 末・Phase 末への先送りをしない。

D1 候補の ingest ルール: [MECHANICAL_OUTER_LOOP.md](MECHANICAL_OUTER_LOOP.md)
