# Backdoor 監査ログアラート

Backdoor API の構造化監査ログ（`stderr` → Cloud Logging `textPayload`）に対するアラート設定ガイド。

ログ形式は JSON 1 行。`event_type` でフィルタする（[`security_audit_log.rs`](../../crates/agrr-server/src/security_audit_log.rs)）。

## 推奨アラート

| ID | 目的 | 条件 | 重大度 |
|----|------|------|--------|
| **ALERT-BACKDOOR-AUTH-FAIL** | トークン漏洩・ブルートフォースの兆候 | 5 分窓で `backdoor_auth_failure` **≥ 5 件** | High |
| **ALERT-BACKDOOR-ADMIN** | 本番 admin 変更（break-glass 含む） | `backdoor_operation` かつ `action` に `user_create:success` / `user_update:success` かつ admin 関連 | Critical |
| **ALERT-BACKDOOR-DB-CLEAR** | 全 DB 削除 | `backdoor_operation` かつ `action=db_clear:success` | Critical |
| **ALERT-BACKDOOR-BLOCKED** | 本番ゲートによる拒否（設定ミス・攻撃試行） | `blocked_production` outcome **≥ 1 件**/時 | Warning |

## ログベースメトリクス（gcloud 例）

プロジェクト ID は環境に合わせて置き換える。

```bash
PROJECT=agrr-475323
SERVICE=agrr-production

# 認証失敗
gcloud logging metrics create backdoor_auth_failure_count \
  --project="$PROJECT" \
  --description="Backdoor API authentication failures" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="'"$SERVICE"'"
    textPayload:"backdoor_auth_failure"'

# DB 全消去成功
gcloud logging metrics create backdoor_db_clear_success_count \
  --project="$PROJECT" \
  --description="Backdoor db/clear succeeded (break-glass)" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="'"$SERVICE"'"
    textPayload:"backdoor_operation"
    textPayload:"db_clear:success"'

# 本番 admin 変更ブロック
gcloud logging metrics create backdoor_admin_blocked_count \
  --project="$PROJECT" \
  --description="Backdoor admin change blocked in production" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="'"$SERVICE"'"
    textPayload:"blocked_production_admin"'
```

## Monitoring アラートポリシー（雛形）

通知チャネル ID を `--notification-channels` に指定する。

```bash
# ALERT-BACKDOOR-AUTH-FAIL: 5 分で認証失敗 5 件以上
gcloud alpha monitoring policies create \
  --project="$PROJECT" \
  --display-name="AGRR Backdoor auth failures" \
  --condition-display-name="backdoor_auth_failure >= 5 in 5m" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="logging.googleapis.com/user/backdoor_auth_failure_count"' \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s \
  --combiner=OR \
  --notification-channels=CHANNEL_ID

# ALERT-BACKDOOR-DB-CLEAR: db_clear 成功 1 件でも即時
gcloud alpha monitoring policies create \
  --project="$PROJECT" \
  --display-name="AGRR Backdoor db/clear succeeded" \
  --condition-display-name="db_clear success >= 1" \
  --condition-filter='resource.type="cloud_run_revision" AND metric.type="logging.googleapis.com/user/backdoor_db_clear_success_count"' \
  --condition-threshold-value=1 \
  --condition-threshold-duration=60s \
  --combiner=OR \
  --notification-channels=CHANNEL_ID
```

## 手動調査クエリ

```bash
# 直近 1 時間の Backdoor 操作
gcloud logging read \
  'resource.type="cloud_run_revision"
   resource.labels.service_name="agrr-production"
   (textPayload:"backdoor_operation" OR textPayload:"backdoor_auth_failure")' \
  --project=agrr-475323 \
  --limit=50 \
  --format=json

# admin 変更ブロックのみ
gcloud logging read \
  'textPayload:"blocked_production_admin"' \
  --project=agrr-475323 \
  --limit=20
```

## Runbook: ALERT-BACKDOOR-AUTH-FAIL

1. `backdoor_auth_failure` の `action`（`invalid_token` / `missing_token`）を確認。
2. 旧トークン由来ならローテーション完了を確認（[`production-admin` §トークンローテーション](../../.cursor/skills/production-admin/SKILL.md)）。
3. 未知のソース IP が多い場合は LB / Cloud Armor で一時遮断を検討。

## Runbook: ALERT-BACKDOOR-DB-CLEAR / ALERT-BACKDOOR-ADMIN

1. 意図した break-glass 作業か運用カレンダーと照合。
2. 意図しない場合: 即時トークンローテーション、影響調査（[`production-primary-sqlite-query`](../../.cursor/skills/production-primary-sqlite-query/SKILL.md)）。
3. break-glass env（`AGRR_BACKDOOR_ALLOW_DB_CLEAR` / `AGRR_BACKDOOR_ALLOW_ADMIN_CHANGES`）が残っていないか Cloud Run を確認。

## 関連

- [backdoor-threat-model.md](backdoor-threat-model.md)
- [core-api-optimization-sli-slo.md](core-api-optimization-sli-slo.md) — 他 SLI/アラートの雛形
