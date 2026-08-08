# コア API / 最適化 SLI・SLO とアラート

**目的**: ユーザー影響ベースの信頼性目標（SLI / SLO）を定義し、アラートとインシデント対応の根拠を明文化する。  
**対象サービス**: Cloud Run `agrr-production`（`agrr-475323` / `asia-northeast1`）  
**関連**: [deploy-server スキル](../.cursor/skills/deploy-server/SKILL.md)、[production-admin スキル](../.cursor/skills/production-admin/SKILL.md)、[production-primary-sqlite-query スキル](../.cursor/skills/production-primary-sqlite-query/SKILL.md)  
**ヘルスエンドポイント**: `/health`, `/up`, `/api/v1/health`（`crates/agrr-server/src/lib.rs`）

本番の目視確認・デプロイ後の手動チェックは **Automation 受け入れ対象外**。ランブック記載で運用する。

---

## SLI / SLO

| SLI | 定義（ユーザー影響） | SLO（28 日ローリング） | エラーバジェット（月） |
|-----|----------------------|------------------------|------------------------|
| **API 可用性** | 認証済み JSON API（`/api/v1/*`）のリクエストのうち、**5xx を返さない**割合 | **99.5%** 成功（5xx 率 ≤ 0.5%） | 約 0.5% × 総リクエスト（例: 100 万 req/月 → 5,000 件まで） |
| **最適化完了率** | プライベート / 公開計画の最適化チェーンが enqueue されてから **30 分以内**に `optimization chain finalized` まで到達した割合 | **95%** 完了（失敗・タイムアウト ≤ 5%） | 約 5% × enqueue 数 |
| **API レイテンシ（P99）** | `/api/v1/*` のエンドツーエンド応答時間（LB + Cloud Run。最適化の非同期ジョブは除外） | **P99 < 5 秒** | P99 が 5 秒超の 1% 未満のリクエストは許容 |

**測定窓**: カレンダー月（UTC）または 28 日ローリング。インシデント判断は **5 分〜1 時間**の短期窓でアラート、月次で SLO レビュー。

**OpenTelemetry**: 別 issue で導入予定の場合は本 doc のログベース指標と併記可。本 issue の完了はログベース SLI で満たす。

---

## 測定方法

### API 可用性（SLI 1）

| 手段 | 内容 |
|------|------|
| **Cloud Monitoring（推奨）** | メトリクス `run.googleapis.com/request_count`（`resource.type=cloud_run_revision`, `service_name=agrr-production`）。`response_code_class` で `5xx` と全体を集計。可用性 = `1 - (5xx / total)`。 |
| **手動クエリ（MQL 例）** | Monitoring → Metrics Explorer で上記メトリクスを `response_code_class` でグループ化。 |
| **ログ補助** | 5xx の原因切り分け: `gcloud logging read` で `httpRequest.status>=500` または `severity>=ERROR` をフィルタ。 |

```bash
# 直近 1 時間の 5xx 件数（ログベース・原因調査用）
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="agrr-production"
   AND httpRequest.status>=500' \
  --project=agrr-475323 \
  --limit=50 \
  --freshness=1h \
  --format='table(timestamp,httpRequest.status,httpRequest.requestUrl)'
```

### 最適化完了率（SLI 2）

| 手段 | 内容 |
|------|------|
| **ログベース指標（推奨）** | `textPayload` のプレーン文字列: `optimization chain enqueued`（分母）と `optimization chain finalized`（分子）。失敗は `optimization_chain` + `outcome=failed` または `optimization failed plan_id=`。 |
| **構造化テレメトリ** | `optimization_chain step=<name> plan_id=<id> ... outcome=ok|failed`（`crates/agrr-server/src/optimization_chain_telemetry.rs`） |
| **DB 補助** | 長期トレンド: Litestream レプリカで `cultivation_plans.status` / `optimization_phase`（[production-primary-sqlite-query スキル](../.cursor/skills/production-primary-sqlite-query/SKILL.md)） |

```bash
# 直近 24h: enqueue vs finalize 件数（手動 SLI 試算）
gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="agrr-production"
   AND textPayload:"optimization chain enqueued"' \
  --project=agrr-475323 \
  --freshness=24h \
  --format='value(textPayload)' | wc -l

gcloud logging read \
  'resource.type="cloud_run_revision"
   AND resource.labels.service_name="agrr-production"
   AND textPayload:"optimization chain finalized"' \
  --project=agrr-475323 \
  --freshness=24h \
  --format='value(textPayload)' | wc -l
```

### API レイテンシ P99（SLI 3）

| 手段 | 内容 |
|------|------|
| **Cloud Monitoring** | `run.googleapis.com/request_latencies`（distribution）。フィルタ: `service_name=agrr-production`, URL パス `/api/v1/` を含む。集計: 99th percentile。 |
| **ログ** | `httpRequest.latency` フィールド（LB 経由リクエストで利用可能な場合） |

---

## アラート

ユーザー影響ベース（原因指標のみのアラートは補助とし、以下を優先する）。

| ID | ユーザー影響 | 条件（例） | 重大度 | Runbook |
|----|--------------|------------|--------|---------|
| **ALERT-API-5XX** | 農家が API 操作（計画・マスタ CRUD 等）に失敗 | 5 分窓で `/api/v1/*` の 5xx 率 **> 1%** かつ 5xx **≥ 10 件** | Critical | [Runbook: API 5xx 急増](#runbook-api-5xx-急増) |
| **ALERT-OPT-FAIL** | 計画最適化が完了せず optimizing 画面が止まる | 1 時間窓で `optimization_chain` の `outcome=failed` が **≥ 5 件**、または finalize/enqueue 比 **< 80%** | High | [Runbook: 最適化失敗率上昇](#runbook-最適化失敗率上昇) |
| **ALERT-API-LATENCY** | API が体感遅延で操作不能 | 15 分窓で `run.googleapis.com/request_latencies` の P99 **> 8 秒**（SLO 5s の 1.6×） | Warning | [Runbook: API レイテンシ悪化](#runbook-api-レイテンシ悪化) |

### Monitoring アラートポリシー作成（gcloud 例）

プロジェクトにポリシーを作成する際の雛形。閾値は本番トラフィックに合わせて調整する。

```bash
# ALERT-API-5XX: Cloud Run 5xx 率（要: 通知チャネル ID を --notification-channels に指定）
gcloud alpha monitoring policies create \
  --project=agrr-475323 \
  --display-name="AGRR API 5xx rate (user impact)" \
  --condition-display-name="5xx rate > 1% over 5m" \
  --condition-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND metric.type="run.googleapis.com/request_count" AND metric.labels.response_code_class="5xx"' \
  --condition-threshold-value=10 \
  --condition-threshold-duration=300s \
  --combiner=OR \
  --notification-channels=CHANNEL_ID

# ALERT-OPT-FAIL: ログベースメトリクス（事前に logging metrics で作成）
# 例: ログフィルタ textPayload:"optimization_chain" AND textPayload:"outcome=failed"
# → logging.googleapis.com/user/optimization_chain_failed_count
```

ログベースメトリクスの作成:

```bash
gcloud logging metrics create optimization_chain_failed_count \
  --project=agrr-475323 \
  --description="Optimization chain step failures (user-visible)" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="agrr-production"
    textPayload:"optimization_chain"
    textPayload:"outcome=failed"'
```

---

## Runbook

### Runbook: API 5xx 急増

1. **確認**: [§測定方法 — API 可用性](#api-可用性sli-1) の `gcloud logging read` で 5xx URL・時刻を特定。
2. **直近デプロイ**: `gcloud run revisions list --service=agrr-production --region=asia-northeast1 --project=agrr-475323 --limit=3`
3. **ロールバック判断**: 新 revision 直後の 5xx なら前 revision へトラフィック切替（[deploy-server スキル](../.cursor/skills/deploy-server/SKILL.md) §緊急復旧）。
4. **エスカレーション**: 認証・DB・agrr デーモン起因を切り分け。`session` / SQLite / `AGRR_DAEMON` ログを確認。

### Runbook: 最適化失敗率上昇

1. **確認**: Cloud Logging で `fetch_weather_data failed` / `optimization failed` / enqueue のみ等の失敗パターンを分類（[`production-primary-sqlite-query` スキル](../../.cursor/skills/production-primary-sqlite-query/SKILL.md) と併用）。
2. **サンプル plan_id**: 失敗ログから `plan_id=` を抽出し DB と突合（[production-primary-sqlite-query スキル](../.cursor/skills/production-primary-sqlite-query/SKILL.md)）。
3. **典型原因**: 気象 API / GCS 読み取り、agrr デーモン未応答、作物ステージ未設定、Cloud Run 再起動によるインメモリキュー喪失。
4. **緩和**: 単一 plan の再 enqueue は backdoor / 管理 API 経路があれば利用。 widespread ならデプロイ・デーモン・参照 fixture を確認。

### Runbook: API レイテンシ悪化

1. **確認**: Monitoring で `run.googleapis.com/request_latencies` の P50/P95/P99 と遅い URL パスを特定。
2. **DB / GCS**: SQLite ロック、GCS 天気読み取りのスパイク（`gcs_reads=` テレメトリ行）を確認。
3. **キャパシティ**: Cloud Run `max-instances`（本番は 1）と同時最適化チェーン数 `OPTIMIZATION_MAX_CONCURRENT_CHAINS` の飽和を疑う。
4. **関連**: [`production-primary-sqlite-query` スキル](../../.cursor/skills/production-primary-sqlite-query/SKILL.md)、[`production-admin` スキル](../../.cursor/skills/production-admin/SKILL.md)

---

## レビュー頻度

| 頻度 | 作業 |
|------|------|
| **週次** | アラート発火履歴・5xx / 最適化失敗の件数トレンド確認 |
| **月次** | 上記 SLI テーブルに対する実績とエラーバジェット消費の記録（Issue / 社内メモ可） |
| **リリース後** | デプロイ直後 30 分は ALERT-API-5XX / ALERT-OPT-FAIL の閾値感度を上げて監視（任意） |

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-08-05 | 初版（issue #602） |
