# lib/domain → Rust 移行プログラム（マスタープラン）

## ゴール

- **完了**: `lib/domain/**/*.rb` のユースケース振る舞いが `crates/agrr-domain` に実装され、Ruby 側は **FFI デリゲートまたは削除**され、既存の **domain-lib / Rails 統合テスト**が GREEN。
- **非ゴール（本プログラム外）**: Rails Controller / Presenter / ActiveRecord Gateway の一括削除、フロントエンド変更、本番ランタイムの Rust 単体サーバー化（将来フェーズで検討）。

## 原則

1. **契約は既存のまま** — Input/Output port・Gateway interface・DTO フィールド名は移行期も変えない（Angular / API 契約を壊さない）。
2. **設計 → R0 テスト → 開発 → パリティの順** — 未テスト表面は **Ruby domain-lib（R0）を先に GREEN** → ゴール記述 → Rust 実装 → R1 パリティ → FFI ブリッジ → Ruby 削除（[`TEST-STRATEGY.md`](./TEST-STRATEGY.md) の R0）。
3. **併走** — Rust 化したモジュールができるまで Ruby `lib/domain` は残す。削除は **パリティ + 統合 GREEN 後**のみ。
4. **Gateway 実装は Ruby のまま** — 移行初期は Interactor / Policy / Mapper / Entity を Rust 化。I/O は `app/adapters` + `CompositionRoot`（ARCHITECTURE.md Gateway boundary）。

## テスト先行バックログ

- 機械可読: [`BACKLOG-test-first.yaml`](./BACKLOG-test-first.yaml)
- Wave-3/4 で Rust 側に `Deferred` コメントのみ残していた項目は **R0 完了まで Rust 拡張しない**
- Wave-5 `cultivation_plan` は G1 インベントリ後、スライス単位で R0 → G2 → G3

## フェーズ（プログラム全体）

| フェーズ | 名称 | 成果物 | 出口基準 |
|---------|------|--------|----------|
| **P0** | 基盤 | `crates/agrr-domain`、CI、`TRACKING` | `cargo test` GREEN、トラッキング全コンテキスト登録 |
| **P1** | shared コア | policies, type_converters, exceptions, value_objects | `shared` の policy 系が Rust パリティ完了 |
| **P2** | 小型 BC | api_keys, auth, backdoor, contact_messages, file_blob, internal_jobs | 各 BC `status: done` |
| **P3** | 中型 BC | deletion_undo, interaction_rule, public_plan, field, agricultural_task, fertilize, pesticide, farm, pest | 同上 |
| **P4** | 大型 BC | field_cultivation, weather_data, crop | 同上 |
| **P5** | 最大 BC | cultivation_plan | 同上 |
| **P6** | FFI カットオーバー | `ext/agrr_domain` + Ruby デリゲート | 重複 Ruby 削除、domain-lib 全 GREEN |
| **P7** | クリーンアップ | `lib/domain` 縮小 / 削除 | 残存 Ruby が shim のみ |

## ウェーブ（コンテキスト束）

`TRACKING.yaml` の `waves` を参照。依存の少ない順:

1. **wave-0-foundation** — ツール・CI・shared の一部（CropPolicy / ReferencableResourcePolicy）
2. **wave-1-shared** — shared 残り（全 policies, ports の型定義, exceptions）
3. **wave-2-small** — 7 コンテキスト（合計 &lt; 50 rb）
4. **wave-3-medium** — 9 コンテキスト
5. **wave-4-large** — field_cultivation, weather_data, crop
6. **wave-5-cultivation-plan** — cultivation_plan のみ（234 rb）

## 1 コンテキストの作業手順（繰り返し）

各 bounded context で、次の **ゲート**を順に通過する（スキップ禁止）。

### G1 設計

- [ ] `TRACKING.yaml` で当該 context の `phase: design`
- [ ] インベントリ: `entities/`, `dtos/`, `interactors/`, `policies/`, `mappers/`, `ports/`, `gateways/`（interface のみ）のファイル一覧
- [ ] Rust モジュールパス割当（`ARCHITECTURE.md` の命名規則）
- [ ] 依存グラフ（他 BC への参照）をメモ
- [ ] ゴール記述（ユースケース単位、禁止条項番号付き）

### G2 開発

- [ ] `phase: dev`
- [ ] `crates/agrr-domain/src/<context>/` に型・ロジック実装
- [ ] Gateway **interface** は Rust `trait` として定義可能だが、**実装はまだ Ruby**

### G3 テスト（パリティ）

- [ ] `phase: test`
- [ ] Ruby `test/domain/<context>/*_test.rb` と同等ケースを `crates/agrr-domain` の `#[cfg(test)]` に移植
- [ ] `run-test-rust-domain.sh` GREEN
- [ ] 既存 `run-test-domain-lib.sh` は **併走 GREEN**（回帰）

### G4 FFI ブリッジ

- [ ] `phase: ffi_bridge`
- [ ] `ext/agrr_domain` から Ruby `Domain::...` を Rust 実装へ委譲
- [ ] 該当 Ruby ファイルに `@deprecated` コメント + 削除予定ウェーブを記載

### G5 完了

- [ ] `phase: done` — Ruby 実装削除（shim のみ残す場合は TRACKING に明記）
- [ ] `sync-lib-domain-rust-tracking.sh` 実行
- [ ] ARCHITECTURE ゲート（該当差分）

## ガバナンス

- **進捗の正**: `TRACKING.yaml` + 再生成された `TRACKING.md`
- **週次**: `TRACKING.md` のサマリー行（完了率）を PR 説明に貼る
- **ブロッカー**: Gateway に残るドメインロジック（P4）→ [`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md) と同じイテレーションで解消してから Rust 化
- **マージ条件**: 新規 Rust モジュールは **パリティテスト必須**；FFI 変更は **domain-lib + 該当 Rails テスト** GREEN

## リスクと対策

| リスク | 対策 |
|--------|------|
| 一括 Big Bang | ウェーブ分割・コンテキスト単位の `done` |
| DTO と AR の漏れ | Snapshot 化を先に完了（field_cultivation 等） |
| FFI デプロイ | P6 まで本番は Ruby 経路維持；Docker に Rust toolchain 追加は P6 着手時 |
| 二重メンテ | TRACKING で `ruby_retained` ファイルを明示 |

## 現在のスナップショット（自動更新）

`./scripts/sync-lib-domain-rust-tracking.sh` 実行後の `TRACKING.md` 先頭サマリーを参照。
