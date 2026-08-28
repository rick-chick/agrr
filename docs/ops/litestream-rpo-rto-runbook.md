# Litestream RPO / RTO とレプリケーション運用

**目的**: 本番 SQLite（エフェメラル `/tmp`）の Litestream レプリケーションについて、データ損失許容（RPO）・復旧時間（RTO）を明文化し、同期設定の評価と遅延アラートの運用根拠を提供する。  
**対象サービス**: Cloud Run `agrr-production`（`agrr-475323` / `asia-northeast1`）  
**関連**: [`config/litestream.yml`](../../config/litestream.yml)、[`scripts/start_agrr_server.sh`](../../scripts/start_agrr_server.sh)、[`scripts/db_bootstrap_common.sh`](../../scripts/db_bootstrap_common.sh)、[production-primary-sqlite-query スキル](../../.cursor/skills/production-primary-sqlite-query/SKILL.md)、[core API SLI/SLO](core-api-optimization-sli-slo.md)

本番の目視確認・デプロイ後の手動チェックは **Automation 受け入れ対象外**。ランブック記載で運用する。

---

## RPO / RTO

| 指標 | 定義 | 目標値（本番） | 根拠 |
|------|------|----------------|------|
| **RPO**（Recovery Point Objective） | Pod 障害・強制終了時に失われうる**未レプリケート書き込み**の最大時間 | **≤ 10 秒**（primary） | `config/litestream.yml` の primary `sync-interval: 10s`。最悪ケースは直前チェックポイント〜障害までの書き込み + 未フラッシュ WAL |
| **RTO**（Recovery Time Objective） | 新 Pod 起動から HTTP 応答可能まで | **≤ 3 分**（通常 **~30 秒**） | `start_agrr_server.sh` で restore は HTTP bind 前に同期実行（~2s）。post-restore bootstrap（migrate / PRAGMA / Litestream replicate）はバックグラウンド |
| **キャッシュ DB RPO** | `production_cache.sqlite3` の未レプリケート書き込み | **≤ 5 分** | cache `sync-interval: 300s`。キャッシュは再生成可能のため primary より緩い |

**許容できない損失**: ユーザーが保存した計画・マスタ・認証データ（primary DB）。キャッシュ喪失は性能劣化のみで許容。

---

## アーキテクチャとリスク

```
┌──────────────── Cloud Run Pod (ephemeral) ────────────────┐
│  agrr-server (HTTP)                                        │
│       │                                                    │
│       ▼                                                    │
│  /tmp/production.sqlite3  ◄── WAL + PRAGMA synchronous     │
│       │                                                    │
│       ▼  litestream replicate (sync-interval: 10s)         │
└───────┼────────────────────────────────────────────────────┘
        │
        ▼
   GCS: production/primary.sqlite3  (retention: 24h)
```

| リスク | 説明 | 緩和 |
|--------|------|------|
| **エフェメラル `/tmp`** | Pod 再起動・障害でローカル DB ファイルが消える | 起動時に GCS から `litestream restore`（`db_bootstrap_common.sh`） |
| **同期間隔** | チェックポイント間の書き込みはレプリカに未反映 | primary `sync-interval` を **30s → 10s** に短縮（issue #1206） |
| **graceful shutdown なし** | SIGKILL / OOM で Litestream が最終 flush できない | RPO 目標を sync-interval ベースで設計。`synchronous=FULL` は採用しない（下記評価） |
| **レプリカ遅延** | GCS オブジェクトがライブより古い | アラート **ALERT-LITESTREAM-LAG**（下記） |

---

## sync-interval / synchronous の評価

### sync-interval（採用値）

| DB | パス | 変更前 | **採用値** | 理由 |
|----|------|--------|------------|------|
| primary | `/tmp/production.sqlite3` | 30s | **10s** | RPO を 30s から 10s に短縮。開発環境 primary と同水準。GCS 書き込み回数は増えるが primary サイズ・書き込み頻度では許容 |
| cache | `/tmp/production_cache.sqlite3` | 300s | **300s**（維持） | 再生成可能。RPO 優先度低 |

**却下した代替案**:

- **1s 以下**: GCS API コスト・Cloud Run CPU スパイク。本番書き込みパターンに対し過剰
- **synchronous replication（Litestream 側）**: v0.3.13 では GCS 向けに別モードなし。間隔短縮が現実的な緩和

### PRAGMA synchronous（採用値）

`db_bootstrap_common.sh` の `apply_pragmas` で **維持**:

```sql
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
```

| 設定 | 評価 | 判断 |
|------|------|------|
| `synchronous = NORMAL` | WAL モードでディスク fsync はコミット時のみ。クラッシュ時は最後のコミット以降が失われうる | **採用** — Cloud Run 単一インスタンス・Litestream チェックポイントと組み合わせて実用 RPO |
| `synchronous = FULL` | 各ページ書き込みを fsync。データ整合性は最大 | **不採用** — API レイテンシ・スループット劣化。エフェメラル `/tmp` + Litestream 構成ではコスト対効果が低い |
| `synchronous = OFF` | 高速だがクラッシュ耐性なし | **不採用** |

**結論**: RPO 緩和は **Litestream sync-interval 短縮** を主軸とし、SQLite は `WAL + synchronous=NORMAL` を維持する。

---

## レプリケーション遅延アラート

| ID | ユーザー影響 | 条件（例） | 重大度 | Runbook |
|----|--------------|------------|--------|---------|
| **ALERT-LITESTREAM-LAG** | Pod 障害時に **10s 超**のデータが失われる可能性 | GCS レプリカ `production/primary.sqlite3` の最終更新から **> 20 秒**（2× sync-interval） | High | [Runbook: レプリカ遅延](#runbook-レプリカ遅延) |
| **ALERT-LITESTREAM-ERROR** | レプリケーション停止 → RPO が際限なく悪化 | 15 分窓で Cloud Run ログに `litestream` + `error` / `ERROR` が **≥ 3 件** | Critical | [Runbook: Litestream エラー](#runbook-litestream-エラー) |

### レプリカ鮮度の手動確認

```bash
# GCS 上の primary レプリカの最終更新時刻（遅延試算）
gcloud storage objects describe \
  "gs://${GCS_BUCKET}/production/primary.sqlite3" \
  --project=agrr-475323 \
  --format='value(updated)'
```

期待: 現在時刻との差が **< 20 秒**（平常時）。デプロイ・大量書き込み直後は一時的に超過しうる。

### ログベースメトリクス（ALERT-LITESTREAM-ERROR）

```bash
gcloud logging metrics create litestream_error_count \
  --project=agrr-475323 \
  --description="Litestream replication errors on agrr-production" \
  --log-filter='resource.type="cloud_run_revision"
    resource.labels.service_name="agrr-production"
    textPayload:"litestream"
    (textPayload:"error" OR textPayload:"ERROR")'
```

### Monitoring アラートポリシー雛形

```bash
# ALERT-LITESTREAM-ERROR（要: 通知チャネル ID）
gcloud alpha monitoring policies create \
  --project=agrr-475323 \
  --display-name="AGRR Litestream replication errors" \
  --condition-display-name="litestream errors >= 3 in 15m" \
  --condition-filter='resource.type="cloud_run_revision" AND resource.labels.service_name="agrr-production" AND metric.type="logging.googleapis.com/user/litestream_error_count"' \
  --condition-threshold-value=3 \
  --condition-threshold-duration=900s \
  --combiner=OR \
  --notification-channels=CHANNEL_ID
```

**ALERT-LITESTREAM-LAG**: GCS オブジェクト更新時刻の定期チェック（Cloud Scheduler + Cloud Functions）または Uptime 的な外部プローブで実装。閾値 **20 秒**（`2 × primary sync-interval`）。

---

## Runbook

### Runbook: レプリカ遅延

1. **確認**: [§レプリカ鮮度の手動確認](#レプリカ鮮度の手動確認) で GCS `updated` と現在時刻の差を計測。
2. **Cloud Run ログ**: `litestream` / `checkpoint` / `sync` を検索し、replicate プロセスが稼働中か確認。
3. **典型原因**: GCS 権限・一時的 API 障害、ディスク I/O 飽和、Pod メモリ不足、デプロイ直後の bootstrap 遅延。
4. **緩和**: 単発なら次チェックポイント（10s 以内）を待つ。持続する場合は revision 再起動または [deploy-server スキル](../../.cursor/skills/deploy-server/SKILL.md) で再デプロイ。
5. **データ影響**: 遅延中に Pod が落ちると、遅延分 + 未チェックポイント分が失われうる。影響範囲は [production-primary-sqlite-query スキル](../../.cursor/skills/production-primary-sqlite-query/SKILL.md) でレプリカを参照。

### Runbook: Litestream エラー

1. **確認**: Cloud Logging で `textPayload:"litestream"` かつ error を直近 1 時間分取得。
2. **GCS バケット**: `GCS_BUCKET` 環境変数・サービスアカウントの `storage.objects.create` 権限を確認。
3. **設定**: コンテナ内 `/etc/litestream.yml` がリポジトリ [`config/litestream.yml`](../../config/litestream.yml) と一致するか（`Dockerfile.agrr-server` で COPY）。
4. **復旧**: replicate プロセスが死んでいれば Pod 再起動。restore 失敗は `bootstrap_strict_restore` により本番起動が拒否される — ログの `restore failed` を優先調査。
5. **エスカレーション**: 24h retention 内の generation 復元が必要な場合は Litestream `restore -generation`（[`production-primary-restore-inner.sh`](../../scripts/production-primary-restore-inner.sh) 参照）。

### Runbook: Pod 障害後のデータ整合性確認

1. 新 Pod が `litestream restore` 完了後に HTTP を公開していることを `/health` で確認。
2. 障害直前のユーザー操作が必要な場合、GCS レプリカのタイムスタンプと [production-primary-sqlite-query スキル](../../.cursor/skills/production-primary-sqlite-query/SKILL.md) でデータを照合。
3. 失われた書き込みは **バックアップからの復元不可**（RPO 内の損失は許容設計）。ユーザー影響が大きい場合はサポート経路で個別対応。

---

## レビュー頻度

| 頻度 | 作業 |
|------|------|
| **週次** | GCS レプリカ鮮度サンプリング（手動または Scheduler） |
| **月次** | RPO/RTO 実績とアラート発火履歴の記録 |
| **設定変更時** | `config/litestream.yml` 変更は本 doc と `verify-litestream-rpo-rto-*` テストを更新 |

---

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2026-08-28 | 初版（issue #1206）— primary sync-interval 30s→10s、RPO/RTO 明文化、アラート定義 |
