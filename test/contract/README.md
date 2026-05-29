# R4 contract tests (P6)

BC ルート切替時に、当該 `test/controllers/api/v1/**` の観測可能な振る舞いを Rust ランタイムでも固定する。

| ゲート | 状態 |
|--------|------|
| Ruby Gateway §P4（read snapshot） | field_cultivation（sync plan read 3 分割、climate_progress）+ cultivation_plan（rest plan / timeline / adjust / optimization read）— 移行済み（2026-05-29） |
| `agrr-adapters-sqlite` | pool + auth session + `FieldCultivationClimateSourceSqliteGateway` |
| `agrr-adapters-gcs` | `WeatherDataGcsReader`（GCS HTTP / ローカル root） |
| `agrr-adapters-agrr` | `AgrrDaemonClient`（Unix socket） |
| `agrr-server` | `/health`, `/auth/*`, `GET /api/v1/auth/me`, `/cable`, `GET /api/v1/plans`, `GET /api/v1/plans/:id`, 部分 `/api/v1/*` |
| `test/contract/**` | R4 複製元 + P6（`auth_me`, plans index/show, cultivation `data`, `task_schedule`, field_cultivation show）+ `contract_test_case.rb` |
| CI `bin.test` | **正**: `scripts/run-rust-contract-tests.sh`（`CONTRACT_RUNTIME=rust`）。Rails デュアルは BC 切替 PR の一時検証のみ |
| dev strangler | `./scripts/rust-only-dev-stack.sh`（`AGRR_RUST_API=1`、Rails なし）+ [`nginx-strangler-host.conf`](../../docker/nginx-strangler-host.conf)（`/api/` → Rust、`location /` は 404） |
| Playwright + Rust | `E2E_STRANGLER=1 E2E_API_ORIGIN=http://127.0.0.1:3000`。**Rust-only** 時は Rails :3001 不要 |
| Rust R4（`CONTRACT_RUNTIME=rust`） | **`scripts/run-rust-contract-tests.sh`**（test コンテナ内で `agrr-server` + `AGRR_SQLITE_PATH=/app/storage/test.sqlite3`）。手動のみの場合は host で server 起動 + `RUST_CONTRACT_BASE_URL` |
| deploy stub | `scripts/deploy-rust-backend-stub.sh` + `Dockerfile.agrr-server` |

- 索引: [`docs/migration/app-rust-stack/README.md`](../docs/migration/app-rust-stack/README.md)
- 正（R4 複製元）: [`PROVISIONAL-STACK.md`](../docs/migration/app-rust-stack/PROVISIONAL-STACK.md)
- 完了条件: [`P6-COMPLETION-CRITERIA.md`](../docs/migration/app-rust-stack/P6-COMPLETION-CRITERIA.md)
- BC 切替 PR チェックリスト: [`P6-BC-CUTOVER-TEMPLATE.md`](../docs/migration/app-rust-stack/P6-BC-CUTOVER-TEMPLATE.md)
- 進捗: [`TRACKING-P6.yaml`](../docs/migration/app-rust-stack/TRACKING-P6.yaml)
- URL map: [`ADR-strangler-lb-url-map.md`](../docs/migration/app-rust-stack/ADR-strangler-lb-url-map.md)
- Sqlite 単体: `cargo test -p agrr-adapters-sqlite`

**P6 切替 PR で必須**（[`P6-BC-CUTOVER-TEMPLATE.md`](../docs/migration/app-rust-stack/P6-BC-CUTOVER-TEMPLATE.md) 1〜7）: 対象 BC の R4 GREEN + URL map（ADR）+ 単一ライター確認。
