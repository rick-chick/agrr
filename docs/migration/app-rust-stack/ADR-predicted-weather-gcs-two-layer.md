# ADR: 予測気象データの GCS 二層化

## Status

Accepted (2026-06-11)

## Context

観測気象バルクは本番で `WEATHER_DATA_STORAGE=gcs` により GCS `weather_data/{location_id}/{year}.json` に置かれ、primary SQLite（Litestream レプリカ対象）はメタデータ中心に保たれている。

一方、予測気象 payload は `cultivation_plans.predicted_weather_data` / `weather_locations.predicted_weather_data` / `farms.predicted_weather_data` の `TEXT` 列に JSON 全文が保存されていた。

本番計測（2026-06-11、Litestream レプリカ復元）:

| テーブル | 行数 | 合計バイト |
|----------|------|------------|
| cultivation_plans | 205 | 28,129,264 |
| weather_locations | 43 | 6,254,405 |
| farms | 0 | 0 |
| **合計** | | **~34 MB** |

primary SQLite の肥大化は Litestream 復元・コールドスタートに影響しうる。予測は agrr デーモンで再生成可能であり、旧 payload の移行は不要。

## Decision

1. **二層構成**: SQLite `predicted_weather_metadata` テーブルにキャッシュ判定用メタデータのみ。payload 本体は GCS `predicted_weather/{scope}/{id}.json`（`scope` = `location` | `plan`）。
2. **旧列削除**: `predicted_weather_data` 3列はマイグレーションで DROP。バックフィルなし（デプロイ後は再予測）。
3. **farm スコープ廃止**: `farms.predicted_weather_data` 列とフォールバック経路を削除。location / plan の2スコープのみ。
4. **キャッシュ判定**: `prediction_end_date` / `data_end_date` / `target_end_date` はメタデータのみで判定。ヒット時のみ GCS から payload を1回読む。
5. **dev/test**: 観測気象と同様 `WEATHER_DATA_LOCAL_ROOT` でローカル FS にミラー可能。

## Consequences

- デプロイ直後は全計画で予測キャッシュミス → 一時的に予測デーモン負荷増。
- Gateway trait を `PredictedWeatherMetadataGateway` + `PredictedWeatherStoreGateway` に分割。`WeatherDataGateway::update_predicted_weather_data` は削除。
- `WeatherLocation` / `CultivationPlanWeather` から payload 埋め込みを除去し、メタデータ DTO に置換。
