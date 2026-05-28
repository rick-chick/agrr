# shared bounded context — P1 設計（G1）

> 生成: 移行プログラム G1。実装状況は [TRACKING.yaml](../TRACKING.yaml) を正とする。

## サマリー

| 指標 | 値 |
|------|-----|
| Ruby ファイル | 52（+ `lib/domain/shared.rb`） |
| domain-lib テスト | 20 |
| Rust モジュール（shared） | 31 `.rs`（2026-05 時点） |

## ウェーブ（本 BC 内）

| ウェーブ | 内容 |
|---------|------|
| **p1a** | policies, type_converters, exceptions, value_objects（純関数） |
| **p1b** | helpers, validation, mappers, dtos（非 HTTP）, `reference_record_*` |
| **p1c** | ports/gateway **trait のみ**, interactors, HTTP 形状 DTO は ADR 後 |

## p1a 状態（2026-05）

| 領域 | 状態 |
|------|------|
| policies（farm, crop, pest, …） | **done** — `crates/agrr-domain/src/shared/policies/` |
| type_converters | **done** |
| exceptions | **done** |
| value_objects | **done**（`ReferenceIndexListFilter`） |
| `crop_nested_pests_access` | **not_started** |
| `pest_crop_association_access` | Ruby @deprecated — Rust は `crop_policy` に統合済み |

## p1b 残

- `reference_record_access_filter.rb`, `reference_record_authorization.rb`
- 残 DTO（`referencable_list_row`, `session_principal`, …）
- `referencable_list_row_mapper.rb`
- `shared.rb` キー変換 — Rust `hash.rs` と統合済み（関数 API）

## p1c 残

- `ports/*` → `src/shared/ports/*.rs`（trait のみ）
- `gateways/*` → trait のみ
- `interactors/masters_api_credentials_resolve_interactor.rb`
- `HttpJsonEnvelope`, `TurboStreamSubscription` — **R3**: Presenter 移管 ADR 推奨

## ARCHITECTURE ブロッカー

| 条項 | 内容 |
|------|------|
| R1 | duck-typed `record` → Rust は `RecordRef` trait 等が必要 |
| R3 | HTTP/Turbo DTO がドメインに残存 |
| — | `list_allowed_sql_params` — Ruby 内参照なし、削除 or enum 化を判断 |

## 実装順（次エージェント）

1. p1c: port/gateway traits
2. p1b: `reference_record_authorization` + mapper
3. G3 再確認: `run-test-rust-domain.sh` + `run-test-domain-lib.sh test/domain/shared/`
4. `shared` → `phase: done` 後、wave-2-small へ

詳細 52 行インベントリは git 履歴または設計セッション fecb2ff5 のエージェント出力を参照。
