# アプリ RUST 化 — スタック調査（アーカイブ）

> **更新**: 2026-05-31  
> **本番の残作業・観測の正**: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)

P6 着手前のスタック調査メモ。**§1–4・6 は 2026-05-29 までに解消**（ActiveStorage スコープ外、ストラングラー ADR、§P4、P0–P5 全 BC `done`、本番 `WEATHER_DATA_STORAGE=gcs`）。詳細の経緯は git 履歴を参照。

## ストレージの前提（運用実態・変更なし）

| 系統 | 実体 | 本番 |
|------|------|------|
| **マスタ DB** | SQLite `primary` / `cache` | Litestream → `GCS_BUCKET` の `production/*.sqlite3` |
| **天気バルク** | GCS `weather_data/{location_id}/{year}.json` | **`WEATHER_DATA_STORAGE=gcs`** |
| **Angular 静的** | 別 GCS + CDN | 変更なし |
| **ユーザー添付** | — | **未使用**（P6 非対象） |

## 未完了（本番切替）

[`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md) を参照（URL map、Rust デプロイ、refinery 初回、必要な `data apply`、切替後スモーク、P7）。

## Rails 正との残差（Rust cutover 後も別タスク）

| 経路 | 備考 |
|------|------|
| **Rails** `Api::V1::InternalController` | AR 天気読み。本番 API が Rust なら未使用 |
| **Rails** `InternalWeatherFetchStartActiveRecordGateway` | Rust は `WeatherDataGatewayBundle` 先行 |
| **Rust** `plan_allocation_adjust_read_gateway` | SQLite `weather_data` 直読み。bundle 化は別タスク |

## 参照

- [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)
- [`ADR-strangler-lb-url-map.md`](./ADR-strangler-lb-url-map.md)
- [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md)
- [`TRACKING-P6.yaml`](./TRACKING-P6.yaml)
- [`../lib-domain-rust/TRACKING.yaml`](../lib-domain-rust/TRACKING.yaml)
