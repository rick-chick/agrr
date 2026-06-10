# Weather data GCS smoke (staging / production)

Manual proof that **Application Default Credentials (ADC)** can read weather bulk objects after write. Automated CI uses `WEATHER_DATA_LOCAL_ROOT` only; this doc covers real GCS + ADC.

## Prerequisites

- Cloud Run (or local) with `WEATHER_DATA_STORAGE=gcs` and `GCS_BUCKET` (or `GCS_WEATHER_DATA_BUCKET`) set.
- Service account with `roles/storage.objectAdmin` (or read/write on the weather prefix).
- agrr-server starts successfully (`validate_weather_storage_config` passes at boot).

## Checklist

1. **Env on Cloud Run**
   - `WEATHER_DATA_STORAGE=gcs`
   - `GCS_BUCKET=<bucket>` (no `WEATHER_DATA_LOCAL_ROOT` in production)
   - Confirm logs at startup mention remote GCS + ADC (not SQLite bulk fallback).

2. **Write path**
   - Trigger internal weather fetch for a test farm (or use existing bulk writer).
   - In GCS console, confirm object exists: `weather_data/<weather_location_id>/<year>.json`.

3. **Read path (ADC)**
   - `GET /api/v1/internal/farms/:id/weather_status` (Rust master) → `weather_data_count > 0` when objects exist.
   - `GET .../field_cultivations/:id/climate_data` → `weather_data.data` non-empty.
   - SQLite primary DB: `SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?` → **0** (bulk not in SQLite).

4. **403 / permission failure must not look like “no data”**
   - Wrong SA or bucket IAM → API returns **5xx** or explicit storage error, **not** `count: 0` with 200.
   - Proof: misconfigure IAM on a staging bucket and confirm `weather_status` / logs surface storage failure (not silent empty).

## Related

- Contract (local_root): `scripts/run-rust-contract-tests.sh`（R4 スモーク）。天気・計画の振る舞いは `agrr-domain` / adapter 単体・E2E
- [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md) — 本番観測の正
