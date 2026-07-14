---

name: gcp-test-local

description: >-

  Operates the GCP test API (Cloud Run agrr-test) and local Angular dev on port 4201

  via same-origin proxy. Use when the user asks for GCP test deploy, agrr-test, or

  verifying test API. On deploy requests: run deploy-rust-backend.sh test and ensure

  ng serve (gcp-test) is listening on http://127.0.0.1:4201. On tear-down requests: run

  teardown-gcp-test.sh (test-only resources; never production).

---



# GCP テスト環境（agrr-test + ローカル UI）



本番（`agrr-production` / `agrr.net` + LB）とは **別サービス・別バケット**。テスト用フロントを GCS に上げても **`agrr-test.net` 用 URL map / DNS が無い限り本番同型にはならない**。ローカル UI は **proxy で同一オリジン**にする（推奨）。



**ローカル UI は常にポート 4201**（`dev-rust-stack` / 通常 `ng serve` の **4200 と競合しない**）。



## エージェント規約（必須）



**`scripts/` ルートにデプロイ用スクリプトを増やさない。** 本スキル配下 [`scripts/`](scripts/) のみ使う。



| やる | やらない |

|------|----------|

| [`scripts/deploy-rust-backend.sh`](scripts/deploy-rust-backend.sh) `test`（末尾で UI 起動まで行う） | `scripts/deploy-gcp-test.sh` 等のルート直下への再追加 |

| tear-down 依頼時 [`scripts/teardown-gcp-test.sh`](scripts/teardown-gcp-test.sh)（本番名はスクリプトが拒否） | `agrr-production` / 本番バケット / `agrr-server` イメージの削除 |

| デプロイ依頼後 **`http://127.0.0.1:4201` で UI が応答する**こと（未起動なら [`start-local-ui.sh`](scripts/start-local-ui.sh)） | 4200 で gcp-test を案内・起動する |

| `env.gcp.test.example` を `.env.gcp.test` の雛形として参照 | 二重 Markdown の新設 |

| 変更は **本スキル内**に最小 diff | `package.json` の `start:gcp-test` などエイリアス量産 |



### GCP テスト「デプロイ」依頼時の手順（エージェント）



ユーザーが GCP テストへのデプロイを依頼したら、**API デプロイとローカル UI 起動の両方**まで完了させる（UI だけ・API だけで終えない）。



1. `deploy-rust-backend.sh test` を実行（内部で Cloud Run 更新後に [`start-local-ui.sh`](scripts/start-local-ui.sh) を呼ぶ）

2. 完了報告に **ブラウザ URL** `http://127.0.0.1:4201` を含める

3. 動作確認: `curl -sf http://127.0.0.1:4201/api/v1/health`（proxy 経由）



UI だけ再起動するとき:



```bash

.cursor/skills/gcp-test-local/scripts/start-local-ui.sh

```



Rails テスト API が必要なときだけ `ENV_GCP_FILE=.env.gcp.test` + [`deploy-server`](../deploy-server/SKILL.md) の `gcp-deploy.sh`。



---



## 構成（固定）



| 項目 | 値 |

|------|-----|

| Cloud Run | `agrr-test`（`asia-northeast1`） |

| DB Litestream | `gs://agrr-test-db` |

| 天気 JSON | `WEATHER_DATA_STORAGE=gcs` + `GCS_WEATHER_DATA_BUCKET`（本番と共有 `agrr-weather-data` が典型） |

| ローカル UI | **`http://127.0.0.1:4201`**（`localhost:4201` 可） |

| ローカル proxy | [`frontend/proxy.conf.gcp-test.cjs`](../../../frontend/proxy.conf.gcp-test.cjs) |

| 環境切替 | [`frontend/src/environments/environment.gcp-test.ts`](../../../frontend/src/environments/environment.gcp-test.ts)（`proxySameOriginApi`） |

| Angular | `ng serve --configuration gcp-test`（`angular.json` で **port 4201**） |

| UI 起動スクリプト | [`scripts/start-local-ui.sh`](scripts/start-local-ui.sh) |



---



## 1. 初回準備



```bash

# リポジトリ root

cp env.gcp.test.example .env.gcp.test

# OAuth / 天気 GCS 等は .env.gcp から手でコピーするか、deploy 前に .env.gcp.test に追記

```



`.env.gcp.test` の `FRONTEND_URL` / `GOOGLE_OAUTH_REDIRECT_URI` は **4201**（example 参照）。



---



## 2. API デプロイ（Rust）+ ローカル UI



```bash

.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh test

```



- `.env.gcp` → `.env.gcp.test` の順で source（test が上書き）

- `GCS_BUCKET` が無ければバケット作成 + SA IAM（スクリプト内のみ）

- 成功後 **自動**で `AGRR_TEST_API_URL` を今回のリビジョン URL に合わせ [`start-local-ui.sh`](scripts/start-local-ui.sh) を実行



デプロイ後 Cloud Run URL（参考）:



```bash

gcloud run services describe agrr-test --region asia-northeast1 --project agrr-475323 \

  --format='value(status.url)'

```



---



## 2.5 Tear-down / 削除（GCP test のみ）



プロジェクト **`agrr-475323` 内の test 専用リソース**を削除する。**本番と共有プロジェクト**のため、対象外を誤って触らないこと。



| 削除対象（test） | 触らない（本番・共有） |

|------------------|------------------------|

| Cloud Run `agrr-test` | `agrr-production` |

| GCS `agrr-test-db`, `agrr-frontend-test` | `agrr-production-db`, `agrr-frontend-prod` 等 |

| Artifact Registry `…/agrr/agrr-test:*` | `agrr-server` 等 |

| — | `agrr-weather-data`、プロジェクト自体、本番 SA / LB |



**手動のまま**: Google OAuth のリダイレクト URI、`agrr-test.net` の DNS（設定済みの場合）。



推奨（対話確認あり）:



```bash

.cursor/skills/gcp-test-local/scripts/teardown-gcp-test.sh

```



非対話（エージェント・CI）: `--quiet`



再構築は [§2](#2-api-デプロイrust--ローカル-ui) の [`deploy-rust-backend.sh`](scripts/deploy-rust-backend.sh) `test` を参照。



### 手動コマンド（スクリプトと同等・参考）



```bash

# 1. Cloud Run

gcloud run services delete agrr-test --region=asia-northeast1 --project=agrr-475323 --quiet



# 2. GCS（オブジェクト削除後にバケット削除）

gcloud storage rm -r gs://agrr-test-db/** --project=agrr-475323

gcloud storage buckets delete gs://agrr-test-db --project=agrr-475323 --quiet

gcloud storage rm -r gs://agrr-frontend-test/** --project=agrr-475323

gcloud storage buckets delete gs://agrr-frontend-test --project=agrr-475323 --quiet



# 3. Artifact Registry（agrr-test イメージのみ）

gcloud artifacts docker images list asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr-test --include-tags

# 一覧の image URI を delete（例）

# gcloud artifacts docker images delete IMAGE_URI --quiet --delete-tags

```



---



## 3. ローカル UI → GCP API（同一オリジン）



```bash

cd frontend

ng serve --configuration gcp-test --host 127.0.0.1

# http://127.0.0.1:4201 （port は angular.json の gcp-test 設定）

```



別リビジョン向け:



```bash

AGRR_TEST_API_URL=https://YOUR.run.app .cursor/skills/gcp-test-local/scripts/start-local-ui.sh

```



ブラウザは `/api` `/auth` `/cable` を **4201 経由**で Cloud Run に転送。`getApiBaseUrl()` は `gcp-test` ビルドで `''`（`:3000` に行かない）。



ログ: `tmp/gcp-test-ng-serve.log` / PID: `tmp/gcp-test-ng-serve.pid`



### OAuth（ログインまで試すとき）



1. Cloud Run `agrr-test` の `FRONTEND_URL` に **`http://127.0.0.1:4201` / `http://localhost:4201`**（`.env.gcp.test` 既定）を入れて **再デプロイ**

2. Google Console に **`http://127.0.0.1:4201/auth/google_oauth2/callback`**（および `localhost:4201` 相当）を追加

3. `agrr-test` は `AGRR_ENV=production` のため **`/auth/test/mock_login` は不可**



---



## 3.5 India 参照データ修復（公開プラン最適化が失敗するとき）

**症状（Cloud Run ログ）**: `optimization failed plan_id=…: crop … has no growth stages`  
**UI（`in` ロケール）**: 「अनुकूलन विफल रहा」など `phase_failed.optimizing`

デプロイだけでは直らない（起動時は `schema run` のみ）。**済みの対処**は India `kind=repair` の `data apply`（`20260531120000` / `20260531130100`）。

```bash
# 推奨: test DB を bootstrap → repair → Litestream 複製 → 通常デプロイに戻す
.cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh
# イメージ済みなら
.cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh --skip-build
```

DB だけ手動で直す場合（レプリカ or コンテナ内）:

```bash
agrr-migrate data apply --region in --kind repair
```

**ローカル開発 DB**（`storage/development.sqlite3`）も同じコマンド。初回セットアップは [`scripts/load-development-reference-data.sh`](../../../scripts/load-development-reference-data.sh)（base のあと repair を含む）。

---

## 4. 動作確認（エージェントが実行）



`SERVICE_URL` は `gcloud run services describe` の値。



```bash

BASE="$SERVICE_URL"



curl -sf "$BASE/up"

curl -sf "$BASE/api/v1/health"

```



**proxy 経由**（`ng serve` / `start-local-ui.sh` 起動後）:



```bash

curl -sf http://127.0.0.1:4201/api/v1/health

```



Rust 応答例: `"environment":"production"` と ISO タイムスタンプ（Rails の `timestamp` 形式と異なる）。



### 天気が GCS か



Cloud Run env（秘密はログに出さない）:



```bash

gcloud run services describe agrr-test --region asia-northeast1 --project agrr-475323 \

  --format='yaml(spec.template.spec.containers[0].env)' | grep -E 'name: (WEATHER|GCS_)'

```



期待: `WEATHER_DATA_STORAGE=gcs`、`GCS_WEATHER_DATA_BUCKET` または `GCS_BUCKET` あり。



**注意**



- `/api/v1/internal/farms/*/weather_*` は **`AGRR_ENV=production` で 403**（dev 専用）。本番同等の制限。

- テスト DB が空なら farm 単位の天気 API は 404/実データなし。バケット `gs://agrr-weather-data/weather_data/` にオブジェクトがあるかは `gcloud storage ls` で別確認。

- `USE_AGRR_DAEMON=true` でもコンテナ内 agrr バイナリが GLIBC 不足で落ちることがある（fetch 系。GCS **読取**とは別）。



### バックドア（任意・トークンは `.env.gcp` から）



```bash

curl -sS -H "X-Backdoor-Token: $AGRR_BACKDOOR_TOKEN" "$BASE/api/v1/backdoor/db/stats"

```



---



## 5. 本番との境界



| | 本番 | GCP テスト |

|---|------|------------|

| デプロイ | [`deploy-server`](../deploy-server/SKILL.md) | **本スキル** [`deploy-rust-backend.sh`](scripts/deploy-rust-backend.sh) `test` |

| 公開 URL | `agrr.net`（LB） | `*.run.app` 直（LB 未設定が通常） |

| ローカル確認 | — | **`http://127.0.0.1:4201`** + proxy |

| フロント静的 | [`deploy-frontend`](../deploy-frontend/SKILL.md) `production` | LB 無しならローカル proxy が現実的 |



---



## 関連



- [`env.gcp.test.example`](../../../env.gcp.test.example)

- [`docs/migration/app-rust-stack/PROVISIONAL-STACK.md`](../../../docs/migration/app-rust-stack/PROVISIONAL-STACK.md)

- 契約テスト（ローカル Docker）: `scripts/run-rust-contract-tests.sh`

- 本番 Rust カットオーバー確認: [`scripts/prod-rust-cutover-checklist.sh`](scripts/prod-rust-cutover-checklist.sh)


