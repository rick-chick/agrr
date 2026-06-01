# R4 contract tests (P6)

BC ルート切替時に、当該 `test/controllers/api/v1/**` の観測可能な振る舞いを Rust ランタイムでも固定する。

| ゲート | 状態 |
|--------|------|
| Ruby Gateway §P4（read snapshot） | field_cultivation（sync plan read 3 分割、climate_progress）+ cultivation_plan（rest plan / timeline / adjust / optimization read）— 移行済み（2026-05-29） |
| `agrr-adapters-sqlite` | pool + auth session + `FieldCultivationClimateSourceSqliteGateway` |
| `agrr-adapters-gcs` | `GcsObjectClient`（ADC read/write/list; 404 のみ空）+ `WeatherDataGcsBulkGateway`。`scripts/run-rust-contract-tests.sh` は `WEATHER_DATA_STORAGE=gcs` + `WEATHER_DATA_LOCAL_ROOT` を既定注入。`internal_farm_weather_contract_test.rb` が GCS fixture で `weather_data_count` / `count > 0` を断言 |
| `agrr-adapters-agrr` | `AgrrDaemonClient`（Unix socket） |
| `agrr-server` | `/health`, `/auth/*`, `GET /api/v1/auth/me`, `/cable`, `GET /api/v1/plans`, `GET /api/v1/plans/:id`, 部分 `/api/v1/*` |
| `test/contract/**` | R4 複製元 + P6（`auth_me`, plans index/show, cultivation `data`, `task_schedule`, field_cultivation show）+ `contract_test_case.rb` |
| CI `bin.test` | **正**: `scripts/run-rust-contract-tests.sh`（`CONTRACT_RUNTIME=rust`）。Rails デュアルは BC 切替 PR の一時検証のみ |
| ローカル Rust 開発 | **[`dev-docker`](../../.cursor/skills/dev-docker/SKILL.md)**（`up.sh` / `host-rust-stack.sh`） |
| Playwright + Rust | `E2E_STRANGLER=1 E2E_API_ORIGIN=http://127.0.0.1:3000`。**Rust-only** 時は Rails :3001 不要 |
| Rust R4（`CONTRACT_RUNTIME=rust`） | **`scripts/run-rust-contract-tests.sh`**（test コンテナ内で `agrr-server` + `AGRR_SQLITE_PATH=/app/storage/test.sqlite3`）。手動のみの場合は host で server 起動 + `RUST_CONTRACT_BASE_URL` |
| Cloud Run deploy | `.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh test` + `Dockerfile.agrr-server` + `start_agrr_server.sh` |

- 索引: [`docs/migration/app-rust-stack/README.md`](../docs/migration/app-rust-stack/README.md)
- 正（R4 複製元）: [`PROVISIONAL-STACK.md`](../docs/migration/app-rust-stack/PROVISIONAL-STACK.md)
- 完了条件: [`P6-COMPLETION-CRITERIA.md`](../docs/migration/app-rust-stack/P6-COMPLETION-CRITERIA.md)
- 本番・P7: [`PRODUCTION-CUTOVER-STATUS.md`](../docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)
- 進捗: [`TRACKING-P6.yaml`](../docs/migration/app-rust-stack/TRACKING-P6.yaml)
- URL map: [`ADR-strangler-lb-url-map.md`](../docs/migration/app-rust-stack/ADR-strangler-lb-url-map.md)
- Sqlite 単体: `cargo test -p agrr-adapters-sqlite`

**P6 完了後の正**: `./scripts/run-rust-contract-tests.sh` が全 contract を含み GREEN（[`P6-COMPLETION-CRITERIA.md`](../docs/migration/app-rust-stack/P6-COMPLETION-CRITERIA.md) レベル 3）。
