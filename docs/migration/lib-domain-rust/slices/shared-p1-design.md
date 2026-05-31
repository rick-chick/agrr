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

## 状態

`shared` は [`TRACKING.yaml`](../TRACKING.yaml) で `phase: done`（2026-05-29）。本スライスの P1 ブロッカー（R1/R3）は実装済み。
