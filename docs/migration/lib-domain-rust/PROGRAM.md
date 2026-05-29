# lib/domain → Rust 移行プログラム（マスタープラン）

## プログラム状態（2026-05-29）

**出口基準を満たし完了**（正: [`TRACKING.yaml`](./TRACKING.yaml) — 全 19 bounded context `phase: done`、サマリー [`TRACKING.md`](./TRACKING.md)）。  
以降の作業は [`app-rust-stack`](../app-rust-stack/) の P6（`agrr-server`・adapter・ルート切替）および adapter §P4 バックログ（[`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md)）。  
スタック調査上の整理: [`app-rust-stack/BLOCKERS-RESPONSE.md`](../app-rust-stack/BLOCKERS-RESPONSE.md) §4。

## ゴール

- **完了**: `lib/domain` と同等のユースケース振る舞いが `crates/agrr-domain` に実装され、当該 bounded context で **R0・R1・R2**（[`TEST-STRATEGY.md`](./TEST-STRATEGY.md)）が GREEN。
- **非ゴール（本プログラム外）**: Rails Controller / Presenter / ActiveRecord Gateway の一括削除、フロントエンド変更、本番 HTTP / adapter 切替・Rails 廃止（[`app-rust-stack`](../app-rust-stack/)）、Ruby `lib/domain` の本番削除。

## 原則

1. **契約は既存のまま** — Input/Output port・Gateway interface・DTO フィールド名は移行期も変えない（Angular / API 契約を壊さない）。
2. **設計 → R0 テスト → 開発 → パリティの順** — 未テスト表面は **Ruby domain-lib（R0）を先に GREEN** → ゴール記述 → Rust 実装 → R1 パリティ（[`TEST-STRATEGY.md`](./TEST-STRATEGY.md) の R0）。
3. **併走** — Rust 化したモジュールができるまで Ruby `lib/domain` は残す。本プログラムの `done` は **Rust パリティ完了**であり、Ruby ファイル削除は必須としない。
4. **Gateway 実装は Ruby のまま** — 移行期は Interactor / Policy / Mapper / Entity を Rust 化。I/O は `app/adapters` + `CompositionRoot`（ARCHITECTURE.md Gateway boundary）。

## テスト先行バックログ

- 機械可読: [`BACKLOG-test-first.yaml`](./BACKLOG-test-first.yaml)
- Wave-3/4 で Rust 側に `Deferred` コメントのみ残していた項目は **R0 完了まで Rust 拡張しない**
- Wave-5 `cultivation_plan` は G1 インベントリ後、スライス単位で R0 → G2 → G3

## フェーズ（プログラム全体）

| フェーズ | 名称 | 成果物 | 出口基準 |
|---------|------|--------|----------|
| **P0** | 基盤 | `crates/agrr-domain`、CI、`TRACKING` | `cargo test` GREEN、トラッキング全コンテキスト登録 |
| **P1** | shared コア | policies, type_converters, exceptions, value_objects | `shared` の policy 系が Rust パリティ完了 |
| **P2** | 小型 BC | api_keys, auth, backdoor, contact_messages, internal_jobs | 各 BC `phase: done` |
| **P3** | 中型 BC | deletion_undo, interaction_rule, public_plan, field, agricultural_task, fertilize, pesticide, farm, pest | 同上 |
| **P4** | 大型 BC | field_cultivation, weather_data, crop | 同上 |
| **P5** | 最大 BC | cultivation_plan | 同上 |

エッジ配線（`agrr-server`・Rust adapter・ルート切替）と Rails 廃止は **P6–P7**（[`app-rust-stack`](../app-rust-stack/)）。

## lib/domain プログラム出口（`app-rust-stack` 着手の前提）

次をすべて満たした時点で、**本プログラムは完了**とし、[`app-rust-stack`](../app-rust-stack/) の P6（`agrr-server`・adapter 移植）を **ブロッカーなしで着手**できる。

> **2026-05-29**: 上記 3 条件を満たす（`TRACKING.yaml` 全 BC `phase: done`）。P6 残ブロッカーは adapter §P4・`agrr-server` 未作成・R4（[`BLOCKERS-RESPONSE.md`](../app-rust-stack/BLOCKERS-RESPONSE.md)）。

1. `TRACKING.yaml` の全 bounded context が `phase: done`
2. リポジトリ全体で **R0・R1・R2** GREEN（`run-test-domain-lib.sh`・`run-test-rust-domain.sh`）
3. `lib/domain` の Interactor / Policy / Mapper / Entity / port 型が `crates/agrr-domain` にパリティ実装済み（Gateway **interface** の trait 含む。実装は Ruby のまま）

**本プログラム完了後も adapter で続ける作業**（lib/domain のブロッカーではない）:

- [`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md) §P4–P5 の adapter 厚み（AR 走査・read snapshot wire・`CompositionRoot` 起動の整理）は **app adapter 移植と同イテレーション**で薄くする
- 別エピック: `public_plan_active_record_gateway` の farm/crop find 等

**新規に `lib/domain` を Rust 化するとき**（過去完了分に遡及しない）: Gateway に業務判断・DTO 組立が残っていれば、Rust 化の前に §P4 と同イテレーションで domain mapper へ逃がす。

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

### G4 完了

- [ ] `phase: done` — R0・R1・R2 GREEN（[`TEST-STRATEGY.md`](./TEST-STRATEGY.md)）
- [ ] `sync-lib-domain-rust-tracking.sh` 実行
- [ ] ARCHITECTURE ゲート（該当差分）

## ガバナンス

- **進捗の正**: `TRACKING.yaml` + 再生成された `TRACKING.md`
- **週次**: `TRACKING.md` のサマリー行（完了率）を PR 説明に貼る
- **マージ条件**: 新規 Rust モジュールは **パリティテスト必須**；該当 BC の **R0 + R1 + R2** GREEN
- **§P4（gateway-domain-logic）**: 上記「プログラム出口」参照。完了後の adapter 残留は app 移植バックログ。新規 Rust 化時のみ「domain mapper へ先に逃がす」を適用

## リスクと対策

| リスク | 対策 |
|--------|------|
| 一括 Big Bang | ウェーブ分割・コンテキスト単位の `done` |
| DTO と AR の漏れ | Snapshot 化を先に完了（field_cultivation 等） |
| Ruby / Rust 二重メンテ | TRACKING で進捗を明示；`done` は Rust パリティ完了を意味する |
| 本番は Ruby 経路のまま | 本プログラムは `agrr-domain` 実装とテスト；本番切替は [`app-rust-stack`](../app-rust-stack/) |

## 現在のスナップショット（自動更新）

`./scripts/sync-lib-domain-rust-tracking.sh` 実行後の `TRACKING.md` 先頭サマリーを参照。
