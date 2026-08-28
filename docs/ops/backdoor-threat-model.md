# Backdoor API 脅威モデル

`AGRR_BACKDOOR_TOKEN` が設定されているとき、`/api/v1/backdoor/*` は **単一 Bearer トークン**で認証される break-glass 運用 API として有効になる。

## アセット

| アセット | 影響 |
|---------|------|
| 全ユーザーデータ（SQLite primary） | 漏洩・改ざん・削除 |
| 管理者権限（`users.admin`） | 参照マスタ編集・全テナント操作 |
| バックドアトークン | 上記 API へのフルアクセス |

## 信頼境界

```text
[運用者端末] --HTTPS--> [LB / Cloud Run agrr-server]
                              |
                              +-- X-Backdoor-Token == AGRR_BACKDOOR_TOKEN
                              +-- 本番追加ゲート（break-glass env）
```

- **外部攻撃者**: トークンなしでは 401/403。トークン漏洩時は Backdoor 全操作が可能（本番では高リスク操作に追加ゲートあり）。
- **内部運用者**: 正当な break-glass 手順でのみ高リスク操作を実行。

## 脅威と緩和

| ID | 脅威 | 影響 | 緩和（実装済み） |
|----|------|------|------------------|
| T1 | トークン漏洩 | 全ユーザー列挙・admin 昇格・（break-glass 時）DB 全消去 | 構造化監査ログ（`backdoor_operation` / `backdoor_auth_failure`）、トークンローテーション手順（[`production-admin`](../../.cursor/skills/production-admin/SKILL.md)） |
| T2 | 本番での誤操作 `db/clear` | 全データ不可逆削除 | 本番既定無効。`AGRR_BACKDOOR_ALLOW_DB_CLEAR=1` 時のみ + `confirmation_token` 必須（#1163） |
| T3 | 本番での誤操作 admin 昇格/剥奪 | 権限昇格・参照マスタ改ざん | 本番既定無効。`AGRR_BACKDOOR_ALLOW_ADMIN_CHANGES=1` 時のみ（#1207） |
| T4 | 監査ログ未検知 | 侵害の遅延発見 | Cloud Logging アラート（[`backdoor-audit-alerts.md`](backdoor-audit-alerts.md)） |
| T5 | ブルートフォース | トークン推測 | トークンは十分なエントロピー（`openssl rand -hex 32` 推奨）。失敗は `backdoor_auth_failure` に記録 |

## 本番 break-glass 操作

| 操作 | 本番既定 | break-glass env | 追加確認 |
|------|---------|-----------------|----------|
| `GET` status/health/users/db/stats | 許可（トークンのみ） | — | — |
| `POST` users（`admin: true`） | **拒否** | `AGRR_BACKDOOR_ALLOW_ADMIN_CHANGES=1` | — |
| `PATCH` users（`admin` フィールドあり） | **拒否** | `AGRR_BACKDOOR_ALLOW_ADMIN_CHANGES=1` | — |
| `POST` db/clear | **拒否** | `AGRR_BACKDOOR_ALLOW_DB_CLEAR=1` | `confirmation_token` = バックドアトークン |

**原則**: break-glass env は作業完了後 **必ず削除して再デプロイ**する。

## 監査ログ

- `event_type=backdoor_operation` — 操作種別と outcome（例: `user_update:blocked_production_admin`）
- `event_type=backdoor_auth_failure` — 認証失敗理由（トークン本体はログに出さない）

実装: `crates/agrr-server/src/security_audit_log.rs`、`crates/agrr-server/src/backdoor/routes.rs`

## 関連

- [backdoor-audit-alerts.md](backdoor-audit-alerts.md) — GCP アラート設定
- [production-admin SKILL](../../.cursor/skills/production-admin/SKILL.md) — 運用手順
- Issue #1163（監査ログ・db/clear 制限）、#1207（admin break-glass・脅威モデル・アラート）
