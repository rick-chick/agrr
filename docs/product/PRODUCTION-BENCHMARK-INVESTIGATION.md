# 本番・実環境ベンチとログ調査

**作成日**: 2026-06-10  
**目的**: 体験フロー（public 計画の最適化）のボトルネックを、本番に近い条件で計測・ログ突合する手順をまとめる。  
**関連**: [PRODUCT-GROWTH-ISSUES.md](PRODUCT-GROWTH-ISSUES.md)（P0-0 pending 84%）、[PRODUCTION-CUTOVER-STATUS.md](../migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)

広告停止中は本番 DB への計画追加が許容しやすく、**読み取り調査 + 限定スモーク**を行う好機とする。コード改善の before/after は **agrr-test** で測り、本番は差分確認に留める。

---

## 1. 調査レイヤ（推奨順）

| 層 | 何を測るか | 本番直叩き | 主な手段 |
|---|---|---|---|
| **A. 本番ログ + DB** | 過去の pending / スタック、ステップ所要時間 | 読み取りのみ | Litestream レプリカ、`gcloud logging read` |
| **B. agrr-test** | 最適化チェーン E2E、改善の before/after | 使わない（別 Cloud Run・別 DB） | `gcp-test-local` スキル + Playwright smoke |
| **C. 本番 Playwright** | CDN + LB + 本番 agrr デーモン込みの体感 | 計画が本番 DB に残る | public plan smoke 1 本のみ |

**高速化の当たりを付ける順序**: A → B →（必要なら）C。

---

## 2. 初回調査の確定事実（2026-06-10）

根拠: 本番 primary SQLite（Litestream GCS レプリカ）+ `frontend/` / `crates/` コード照合。

### 2.1 北極星との関係

| 指標 | 値（5月以降・外部流入 user_id NULL） |
|---|---|
| 最適化完了率 | completed 58 / 591 ≒ **10%** |
| pending | **496**（84%）— 全件作物選択済み |
| private 計画 | **0**（登録 35 人中 0） |

### 2.2 pending 496 の内訳（技術切り口）

| status | optimization_phase | 件数 | 解釈 |
|---|---|---|---|
| pending | NULL | **123** | `created_at = updated_at`。**ジョブ未実行**（enqueue 前後の喪失疑い） |
| pending | fetching_weather | **373** | 作成後 0.03〜0.2 秒で phase 更新。**気象取得開始後に停止** |
| optimizing | initializing / fetching_weather | **13** | 更新が止まった**スタック疑い** |
| completed / failed | — | 58 / 22 | 完了・失敗 |

地域（参照農場）: us 313 / in 233 / jp 43。

### 2.3 コード上の制約（ボトルネック候補）

- 最適化は **プロセス内メモリ** の `JobChainDispatcher`（`crates/agrr-server/src/jobs.rs`）。**Cloud Run 再起動・デプロイでキュー消失**。
- 本番 Cloud Run: **max-instances 1**、同時チェーン上限デフォルト **5**（`OPTIMIZATION_MAX_CONCURRENT_CHAINS`）。
- 計画作成 API 成功時に `enqueue_private_plan_optimization_chain` は呼ばれる（`PublicPlanCreateInteractor`）。**クライアントが `/optimizing` を開かなくてもサーバ側ジョブは enqueue される**。

初期仮説（§2.5 で精査済み）: スパイク × 単一インスタンス × 非永続ジョブ。**123 件はインメモリ喪失より Rust 最適化未デプロイ空白（約 58h）**、**373 件は Rails 気象ジョブの途中停止**が主因。

### 2.4 ログ突合（2026-06-10 再実施）

根拠: 上記 SQL 再取得 + `gcloud logging read`（`agrr-production`、60d）でサンプル `plan_id` を突合。

| plan_id | DB status / phase | ログ上の事実 | 解釈 |
|---|---|---|---|
| 646〜650 | pending / NULL | **ログ 0 件**（`enqueued`・`finalized`・Rails `FetchWeather` いずれも無し） | **enqueue 未実行**（API 成功後のジョブ喪失線） |
| 651 | completed（隣接 ID は finalized ログあり） | `optimization chain enqueued` → `finalized` | 正常完了の境界例（650 は無ログ・651 は有ログ） |
| 652 | optimizing / fetching_weather | `enqueued` → `fetch_weather_data failed: InvalidWeatherApiResponse` → 再 `enqueued` のみ | 気象 API 失敗後スタック |
| 653 | optimizing / initializing | `enqueued` のみ（2026-05-31） | チェーン途中停止疑い |
| 526, 527 | pending / fetching_weather | **Rails 時代**の `FetchWeatherDataJob` + ActionCable（2026-05-29） | Rust 切替前の未完了。373 件の大半は同型の可能性 |
| 726 | optimizing / fetching_weather ※ | `enqueued` → `finalized`（2026-06-09 23:54 UTC） | ※ログは完了だが DB は未更新のまま（`updated_at` が finalize より前）。レプリカ遅延または status 更新漏れ要確認 |

Rust 本番で観測できた **enqueue → finalize** 所要（ログ時刻差）:

| plan_id | 所要 |
|---|---|
| 726 | 18.9s |
| 725 | 29.9s |
| 722 | 26.6s |
| 720 | 97.0s |

**結論（Phase A）**: 取りこぼしは単一原因ではない。§2.5 の 3 バケットに分解できる。

### 2.5 取りこぼし精査（2026-06-10）

根拠: 本番 DB 日別・plan_id 帯・時間帯集計、Cloud Run revision 一覧、`optimization chain enqueued` / `FetchWeatherDataJob` の最古ログ、git `1e63157c`（optimization chain 接続）の日時。

#### 2.5.1 3 バケット（pending 496 + optimizing 13 = 未完了 509 件）

| バケット | 件数 | plan_id 帯 | 期間 | DB 上の形 | 根拠となる一次事実 |
|---|---|---|---|---|---|
| **A. Rails 気象スタック** | **373** | &lt; 528 | 5/12〜5/28（ピーク 5/21〜28） | `pending` / `fetching_weather`（phase 更新あり） | Rails `FetchWeatherDataJob` ログ。完了率 **9/(9+7+373) ≒ 2%** |
| **B. Rust カットオーバー空白** | **123** | 528〜650 | 5/29 02:37〜5/31 12:50 UTC | `pending` / NULL（`created_at = updated_at`） | **`optimization chain enqueued` 最古ログ = 5/31 12:51 UTC（plan 651）**。この帯は enqueue ログ **0 件** |
| **C. Rust 途中停止** | **13** | 651〜680 中心 | 5/31 12:51〜6/1 頃 | `optimizing` / `initializing` or `fetching_weather` | enqueue ログあり。`fetch_weather_data failed: InvalidWeatherApiResponse` 等 |

地域（us / in / jp）は 3 バケットとも流入比率と同型（us 最多）。**離脱 UI よりインフラ・移行タイミングの説明力が大きい。**

#### 2.5.2 タイムライン（確定）

```
5/21〜28  広告スパイク（50〜59 件/日）→ Rails FetchWeather 開始後スタック（バケット A）
5/29 02:32 UTC  Cloud Run revision 00148（Rust API 初デプロイ）
5/29 02:37      plan_id=528〜（Rust で計画 CREATE 開始・optimization 未接続）
5/30 14:49 JST  git 1e63157c「connect optimization chain to agrr daemon」（未デプロイ）
5/31 12:51 UTC  初めて optimization chain enqueued（plan 651）
5/31 13:00〜    完了が時間帯集計に出現（以降はバケット B 終了）
6/1〜           rust_stable（id>680）完了率 ≒ 72%。Phase C（6/10）も 11.9s で完了
```

**バケット B の空白は約 58 時間**（Rust で計画だけ受け付け、最適化パイプラインが本番に無かった期間）。インメモリ喪失の仮説より **デプロイギャップ** が先に確定する。

#### 2.5.3 日別内訳（外部流入・user_id NULL）

| 日付 | pending NULL | pending FW | completed | 解釈 |
|---|---|---|---|---|
| 5/21〜28 | 0 | 20〜59/日 | 0〜2/日 | バケット A のみ |
| 5/29 | 48 | 6 | 0 | 移行日。FW 6 件は Rails 残り（522〜527）、以降 NULL |
| 5/30 | 37 | 0 | 0 | バケット B のみ |
| 5/31 | 38（〜12:00） | 0 | 13（12:51〜） | 12:51 UTC 以降はバケット C 混在 |
| 6/1〜 | 0 | 0 | 大半 completed | 正常化 |

#### 2.5.4 plan_id 帯別の完了率

| 帯 | completed | failed | pending / optimizing | 完了率（completed / 全件） |
|---|---|---|---|---|
| rails_era（&lt;528） | 9 | 7 | 373 pending | **2.3%** |
| rust_gap（528〜650） | 0 | 0 | 123 pending | **0%** |
| rust_early（651〜680） | 16 | 5 | 9 optimizing | **50%** |
| rust_stable（&gt;680） | 35 | 10 | 4 optimizing | **72%** |

#### 2.5.5 コード上の enqueue 経路（再確認）

- `PublicPlanCreateInteractor` は plan 作成成功後に **必ず** `enqueue_after_create` を呼ぶ（gateway が `Some` のとき）。
- `enqueue_private_plan_optimization_chain` は plan 存在確認後 **`optimization chain enqueued` をログしてから** インメモリ dispatcher に投入（`optimization_job_chain.rs`）。
- バケット B でログが無い = **当該 revision ではこの経路が本番に載っていなかった** と整合。plan not found ログも 60d で **0 件**。

#### 2.5.6 結論と対応の優先順

| 優先 | 対象 | 施策 |
|---|---|---|
| 1 | バケット B（123）+ A（373）の既存 plan | **再起動時 re-enqueue / バックフィル Job**（`optimization-chain-run` または永続キュー導入後の一括回収） |
| 2 | バケット C（13） | 同上 + 気象 API 失敗の個別調査 |
| 3 | 再発防止 | 永続キュー or デプロイ後の **pending 再スキャン**；カットオーバー時は CREATE と optimization を同一 revision で出す |
| 低 | UX 離脱 | 現行スタック（rust_stable）では最適化自体は動く。離脱単独では 84% を説明できない |

**現状（6/10）**: 新規作成は Phase C で 11.9s 完了。問題は **5月に溜まった 509 件の回収** と **同型の再発防止**。

---

## 3. 層 A — 本番 DB（読み取り）

スキル: [production-primary-sqlite-query](../../.cursor/skills/production-primary-sqlite-query/SKILL.md)

スクリプトに実行権限がない、または CRLF で失敗する場合:

```bash
sed 's/\r$//' .cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh \
  | bash -s -- "SELECT status, optimization_phase, COUNT(*) FROM cultivation_plans WHERE plan_type='public' AND created_at >= '2026-05-01' GROUP BY status, optimization_phase ORDER BY COUNT(*) DESC;"
```

### 3.1 よく使う SQL

```sql
-- status × phase クロス集計（5月以降・匿名セッション）
SELECT status, optimization_phase, COUNT(*)
FROM cultivation_plans
WHERE plan_type = 'public' AND created_at >= '2026-05-12' AND user_id IS NULL
GROUP BY status, optimization_phase
ORDER BY COUNT(*) DESC;

-- ジョブ未着手（created = updated）
SELECT COUNT(*) FROM cultivation_plans
WHERE status = 'pending' AND optimization_phase IS NULL
  AND created_at = updated_at AND created_at >= '2026-05-01';

-- スタック疑い（optimizing のまま古い）
SELECT id, status, optimization_phase, created_at, updated_at
FROM cultivation_plans
WHERE status = 'optimizing' AND plan_type = 'public'
ORDER BY updated_at ASC LIMIT 20;
```

レプリカは Litestream 同期間隔分だけライブより遅れる可能性あり（書き込み・変更は行わない）。

---

## 4. 層 A — Cloud Run ログ

プロジェクト・サービス（本番）: `agrr-475323` / `agrr-production`（[deploy-server スキル](../../.cursor/skills/deploy-server/SKILL.md)）。

### 4.1 ログに出るキーワード

本番 stdout（`textPayload`）で実際にヒットするのは主に次の **プレーン文字列**（tracing の `message` キー）である。`optimization_chain.bootstrap` / `job chain step start` はコード上は `tracing::info!` だが、2026-06-10 時点の Cloud Logging では `textPayload` 検索にヒットしなかった（フォーマット差の可能性）。

| キーワード（textPayload） | 意味 |
|---|---|
| `optimization chain enqueued plan_id=` | チェーン enqueue 成功 |
| `optimization chain finalized plan_id=` | チェーン完了（`field_cultivations` 付き） |
| `optimization failed plan_id=` | 最適化ステップ失敗（例: `crop N has no growth stages`） |
| `fetch_weather_data failed plan_id=` | 気象取得失敗（例: `InvalidWeatherApiResponse`） |
| `[FetchWeatherDataJob]`（Rails 時代） | 2026-05 下旬以前の ActiveJob 経路 |

コード参照: `crates/agrr-server/src/optimization_job_chain.rs`（enqueue ログ）、`crates/agrr-server/src/optimization_chain_run.rs`（bootstrap の `duration_ms` は tracing）、`crates/agrr-server/src/jobs.rs`（step start/done は tracing）。

### 4.2 取得例

```bash
# チェーン全体（推奨フィルタ）
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="agrr-production"
   AND textPayload:"optimization chain"' \
  --project=agrr-475323 \
  --limit=100 \
  --format='table(timestamp,textPayload)' \
  --freshness=30d

# 特定 plan_id（DB サンプル取得後）
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="agrr-production"
   AND textPayload:"plan_id=650"' \
  --project=agrr-475323 \
  --limit=20 \
  --format='table(timestamp,textPayload)' \
  --freshness=60d
```

調査手順:

1. サンプル `plan_id`（pending / optimizing）を DB から取得
2. ログで同一 `plan_id` の bootstrap → fetch_weather → … の有無を確認
3. **enqueue 後に step ログが一度も無い** → インメモリキュー喪失線が濃い
4. `fetching_weather` で止まる → 気象 API / GCS / デーモン / タイムアウト（600s）を疑う

構造化ログ（JSON）の場合は `jsonPayload.message` もフィルタに含める。

---

## 5. 層 B — agrr-test + Playwright（再現ベンチ）

スキル: [gcp-test-local](../../.cursor/skills/gcp-test-local/SKILL.md)

本番 DB を汚さず、**同じ Rust スタック**で最適化 E2E の所要時間を測る。改善の before/after はここで行う。

### 5.1 前提

- agrr-test デプロイ + ローカル UI `http://127.0.0.1:4201`（proxy 同一オリジン）
- dev-docker ローカル（`:3000`）でも同型 smoke は可能（`E2E_STRANGLER=1`）

### 5.2 計測対象 spec

`frontend/e2e/smoke/public-plan-create-flow.spec.ts`

- ウィザード → 最適化（Cable）→ 結果まで
- アタッチ: `msToResults`（optimizing 画面到達〜results URL）、`cableFrames`、`planId`
- タイムアウト: 180s（最適化待ち 90s）

### 5.3 実行例（ローカル API）

```bash
# 別ターミナル: .cursor/skills/dev-docker/scripts/host-rust-stack.sh 等で :3000 を起動

cd frontend
E2E_CAPTURE_DEV_SESSION=1 \
E2E_STRANGLER=1 \
E2E_API_ORIGIN=http://127.0.0.1:3000 \
npx playwright test e2e/smoke/public-plan-create-flow.spec.ts --reporter=json
```

`npm run test:e2e:smoke` は `e2e/smoke/` 配下 **全 spec** も走るため、ベンチ計測は上記の **単一 spec 指定**を使う。`msToResults` は JSON reporter の attachments（base64）または HTML report で参照。

### 5.4 agrr-test API を向ける場合

`E2E_API_ORIGIN` を agrr-test の公開 URL（gcp-test スキル記載のオリジン）に差し替える。`baseURL`（Angular）は 4201 proxy、`getApiBaseUrl()` 同一オリジン設計のため **API だけ test 向け**にできる。

地域別ベンチ案: 公開フローで us / in / jp 参照農場をそれぞれ 1 回ずつ選択し、`msToResults` を比較。

---

## 6. 層 C — 本番 Playwright（限定スモーク）

### 6.1 できること

- `baseURL=https://agrr.net`（または LB 経由の正規 URL）
- public plan 体験 1 本の所要時間 + 本番ログ `plan_id` 突合

### 6.2 制約

| 項目 | 内容 |
|---|---|
| mock ログイン | 本番では `/auth/test/mock_login_as/*` **無効**（`runtime_env::dev_environment_allowed()`） |
| データ | public 計画が本番 SQLite に **残る** |
| スループット | max-instances=1 — 連続実行はキュー・再起動の影響を受ける |
| スコープ | **全ルート PNG キャプチャ（156 枚・約 1.5h）は本番非推奨** — dev / agent-review 用 |

### 6.3 手順

**public plan は匿名セッションで完結**するため OAuth は不要（private 計画スモーク時のみ §6.2 の storageState が要る）。

1. ローカルに `e2e/.auth/dev-session.json` があると `ensureE2eBaseline` が本番 API に POST して 401 になる。**本番実行時は `E2E_PRODUCTION=1`**（spec 側で baseline をスキップ）。
2. 単一 spec のみ実行（`playwright.production-smoke.config.ts` — workers=1、webServer なし）:

```bash
cd frontend
E2E_PRODUCTION=1 \
E2E_API_ORIGIN=https://agrr.net \
npx playwright test e2e/smoke/public-plan-create-flow.spec.ts \
  --config=playwright.production-smoke.config.ts \
  --reporter=json
```

3. 完了後、ライブ API / Litestream レプリカ / ログで `plan_id` を突合（レプリカは同期遅延で `optimizing` のまま見えることがある → **`GET /api/v1/public_plans/cultivation_plans/{id}/data` を正**）。

---

## 7. サーバ単体のチェーン実行（ローカル / Job）

計画 ID 指定でチェーンを手動実行（デーモン・DB パス要）:

```bash
AGRR_SQLITE_PATH=storage/development.sqlite3 \
  cargo run -q -p agrr-server --bin optimization-chain-run -- --plan-id <ID>
```

本番同等イメージでの agrr CLI・調査 Job: [production-admin](../../.cursor/skills/production-admin/SKILL.md) の `run-production-agrr-cli.sh`（**ライブ revision 非接触**）。

pending 回収の設計（永続キュー・再起動時 re-enqueue）は別タスク。本ドキュメントは**観測手順**に限定する。

---

## 8. 高速化の検討観点（ログ・ベンチ後）

優先度は計測結果で確定する。候補の整理:

| 観点 | 内容 |
|---|---|
| **信頼性** | インメモリジョブ → 永続キュー or 再起動時の未完了 plan 再 enqueue |
| **気象取得** | `fetching_weather` で止まる割合、GCS キャッシュヒット、agrr デーモン latency |
| **並列** | `OPTIMIZATION_MAX_CONCURRENT_CHAINS`（既定 5）と max-instances=1 のバックログ |
| **タイムアウト** | Cloud Run request timeout 600s と最長チェーンの関係 |
| **UX** | 進捗・再試行 UI（サーバ信頼性改善後に効果測定） |

改善効果は **P0-5 ファネルイベント**（[PRODUCT-GROWTH-ISSUES.md](PRODUCT-GROWTH-ISSUES.md)）とセットで見る。

---

## 9. やらないこと

- 本番で `e2e:capture-for-agent` 全ルート × 3 言語（負荷・データ・時間）
- 本番で mock ログイン有効化（`ENABLE_MOCK_AUTH=1`）— セキュリティ上避ける
- ログ・DB 調査なしでの最適化コードの大規模変更
- Litestream レプリカへの書き込み

---

## 10. 関連スキル・ファイル

| 種別 | パス |
|---|---|
| 成長課題一覧 | [PRODUCT-GROWTH-ISSUES.md](PRODUCT-GROWTH-ISSUES.md) |
| 本番 DB 照会 | `.cursor/skills/production-primary-sqlite-query/` |
| 本番運用 | `.cursor/skills/production-admin/` |
| GCP test | `.cursor/skills/gcp-test-local/` |
| Playwright smoke | `frontend/e2e/smoke/public-plan-create-flow.spec.ts` |
| Playwright 設定（dev） | `frontend/playwright.config.ts` |
| Playwright 設定（本番スモーク） | `frontend/playwright.production-smoke.config.ts` |
| ジョブチェーン | `crates/agrr-server/src/optimization_job_chain.rs` |
| Cloud Run デプロイ | `.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh` |

---

## 11. チェックリスト（実施記録用）

```
Phase A（本番・読み取り）— 2026-06-10 実施
[x] pending 内訳 SQL を再取得（日付メモ）— §2 表と同一（pending 496、内訳不変）
[x] サンプル plan_id 10件をログと突合 — §2.4 参照（646〜650 はログ無し、651 は finalized 等）
[x] ステップ別 duration の傾向をメモ — enqueue→finalize 19〜97s（§2.4）。bootstrap / step の tracing は Cloud Logging 未検出

Phase B（agrr-test または local）— 2026-06-10 実施
[x] public-plan-create-flow 1回以上 GREEN — host-rust-stack :3000、commit 6e35257e
[x] msToResults を記録 — plan_id=178、msToResults=855ms（dev・jp 参照農場・気象キャッシュ想定）
[ ] 改善前後で同手順を再実行 — コード改善後に再計測（agrr-test は Cloud Run 未デプロイのため local で代替）

Phase C（本番）— 2026-06-10 実施
[x] public plan 1 本のみ実行 — `E2E_PRODUCTION=1` + `playwright.production-smoke.config.ts`
[x] plan_id を本番 DB・ログで確認 — plan_id=729（§11.2）
[x] 本番と test の msToResults 差分をメモ — 本番 11.9s vs local 0.9s（§11.2）
```

### 11.1 Phase B 計測メモ（2026-06-10）

| 項目 | 値 |
|---|---|
| 環境 | `host-rust-stack.sh`（`E2E_STRANGLER=1`、`E2E_API_ORIGIN=http://127.0.0.1:3000`） |
| commit | `6e35257e` |
| plan_id | 178 |
| msToResults | 855ms（optimizing URL 到達〜results URL） |
| 備考 | 本番 enqueue→finalize は 19〜97s。ローカルは参照データ・気象キャッシュで短い。agrr-test Cloud Run サービスは未存在（`gcloud run services describe agrr-test` → Not Found） |

### 11.2 Phase C 計測メモ（2026-06-10）

| 項目 | 値 |
|---|---|
| 環境 | `https://agrr.net`（CDN + LB + agrr-production）、`E2E_PRODUCTION=1` |
| commit | `6e35257e`（フロント未デプロイ差分は Playwright 設定・spec のみ） |
| plan_id | **729** |
| msToResults | **11,878ms**（optimizing URL 到達〜results URL） |
| ライブ API | `status=completed`、`cultivations=4` |
| Cloud Run ログ | `optimization chain finalized plan_id=729 field_cultivations=4`（09:35:25 UTC） |
| Litestream レプリカ | 直後は `optimizing/predicting_weather`（同期遅延。plan 726 と同型） |
| 選択農場 | ウィザード先頭カード（jp 参照農場・三重） |

**本番 vs local（Phase B）**: msToResults **11.9s vs 0.9s**（約 14 倍）。本番は GCS 気象・デーモン・単一インスタンスの実経路。キュー空き時の体感は 10〜30s 台で、5月スパイク時の未完了（§2.4）とは別問題（信頼性・取りこぼし）。
