---
name: dev-docker
description: >-
  Local development: Docker Compose (agrr-server + strangler-proxy :3000) and
  host cargo alternative. Use for compose up/down, reference data load, Rails
  shell profile, or host-rust-stack.
disable-model-invocation: false
---

# 開発 Docker（dev-docker）

**単一の所在**: 本スキル配下のみ。`scripts/` 直下に Compose 開発用スクリプトを増やさない。

## ディレクトリ

| 配下 | 役割 |
|------|------|
| [`scripts/`](scripts/) | **ホストから実行**（`up.sh`, `load-reference-data.sh`, `host-rust-stack.sh` 等） |
| [`entrypoints/`](entrypoints/) | **コンテナ内のみ**（Compose / `Dockerfile.agrr-server` が参照） |

共有の本番系は [`scripts/`](../../../scripts/) に残る（`db_bootstrap_common.sh`, `run-agrr-migrate.sh`, `start_agrr_server.sh`）。

## エージェント規約

| やる | やらない |
|------|----------|
| 本スキル `scripts/` で操作 | `scripts/docker-entrypoint-dev*.sh` 等を `scripts/` に復活させる |
| 初回 DB: `load-reference-data.sh`（Docker）または `load-reference-data-host.sh`（cargo） | `bundle exec rails db:prepare` |
| API 開発: `up.sh` | 無 profile の `docker compose up web` |
| **`crates/` の Rust API 変更後**: `rebuild-restart.sh`（Docker 利用時は**必須**） | 再ビルドなしで「ブラウザをリロード」とだけ案内する |
| ローカル検証前に API が新フィールドを返すか確認する | 古いバイナリのまま UI 差分だけを見る |

**なぜ再ビルドが要るか**: `agrr-server` はイメージ内の release バイナリ。`docker-compose.yml` は `lib/core` 等のみ bind mount し、`crates/` はマウントしない。API レスポンス（例: `remediation_crops`）を変えたら再ビルドしないと古い JSON のまま。

**Compose**: [`docker-compose.yml`](../../../docker-compose.yml)

## 手順

### 初回 DB

```bash
# 天気 fixture（GCS）— 初回 clone 後。gcloud ADC または AGRR_FIXTURES_SOURCE_DIR
scripts/ensure-reference-fixtures.sh
.cursor/skills/dev-docker/scripts/load-reference-data.sh      # storage_dev_data volume
# または（ホスト cargo）
.cursor/skills/dev-docker/scripts/load-reference-data-host.sh
```

`load-reference-data*.sh` は `AGRR_FIXTURES_REQUIRED=1` で ensure を先に実行する。オフラインのみ `AGRR_FIXTURES_SKIP=1`。メンテナ向け upload: `scripts/publish-reference-fixtures.sh`（要 `gcloud`）。

### 起動・停止（Docker）

```bash
.cursor/skills/dev-docker/scripts/build.sh    # イメージ変更後
.cursor/skills/dev-docker/scripts/up.sh
.cursor/skills/dev-docker/scripts/up.sh --watch   # crates 変更で自動再ビルド（推奨: API 開発中）
.cursor/skills/dev-docker/scripts/rebuild-restart.sh   # 1 回だけ再ビルド＋再起動（エージェントは API 変更後に実行）
.cursor/skills/dev-docker/scripts/down.sh
.cursor/skills/dev-docker/scripts/logs.sh
```

Angular: `cd frontend && ng serve --host 127.0.0.1` → `http://127.0.0.1:3000`

**Docker + API 変更後の確認**: `rebuild-restart.sh` 完了後、ブラウザで対象ページをリロードする（フロントは HMR、API は再ビルドが必要）。

### ホスト cargo（Docker なし）

```bash
.cursor/skills/dev-docker/scripts/load-reference-data-host.sh
.cursor/skills/dev-docker/scripts/host-rust-stack.sh
.cursor/skills/dev-docker/scripts/host-rust-stack.sh stop
```

### Rails シェル（レガシー）

```bash
.cursor/skills/dev-docker/scripts/rails-up.sh
```

`:3000` 競合に注意（Rust スタックと同時に使わない）。

## スクリプト（`scripts/`）

| ファイル | 用途 |
|----------|------|
| `up.sh` / `down.sh` / `build.sh` / `logs.sh` | Compose 操作 |
| `rebuild-restart.sh` | agrr-server 再ビルド＋再作成＋ヘルス待ち |
| `load-reference-data.sh` | コンテナ経由で参照データ投入 |
| `load-reference-data-host.sh` | ホスト `cargo run -p agrr-migrate` |
| `host-rust-stack.sh` | ホスト agrr-server + nginx :3000 |
| `rails-up.sh` | `--profile rails up web` |

## エントリポイント（`entrypoints/`）

| ファイル | サービス |
|----------|----------|
| `docker-entrypoint-dev-rust-stack.sh` | `agrr-server`（イメージ内 `/app/dev-docker-entrypoints/`） |
| `load-reference-data-container.sh` | `compose run agrr-server` |
| `docker-entrypoint-dev-daemon.sh` | profile `rails` → `web`（bind mount `.:/app`） |
| `docker-entrypoint-dev.sh` | profile `rails` → `web-cli` |

## 関連

- P8: [`docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md`](../../../docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)
- テスト: [`test-common`](../test-common/SKILL.md)
- GCP test: [`gcp-test-local`](../gcp-test-local/SKILL.md)
