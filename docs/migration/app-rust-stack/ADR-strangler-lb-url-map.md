# ADR: ストラングラー配線 — 二 Cloud Run サービス + グローバル URL map

> **ステータス**: 確定（2026-05-29）  
> **決定者**: プロダクト / 移行プログラム（スタック調査ブロッカー解消）  
> **関連**: [PROVISIONAL-STACK.md](./PROVISIONAL-STACK.md)、[PRODUCTION-CUTOVER-STATUS.md](./PRODUCTION-CUTOVER-STATUS.md)、[load-balancer-update スキル](../../../.cursor/skills/load-balancer-update/SKILL.md)

## コンテキスト

- 本番は `agrr.net` 単一オリジン（Angular CDN + API + OAuth + WebSocket）。
- OAuth **案 A**（`https://agrr.net/auth/google_oauth2/callback` 維持）のため、パブリック URL は変えず **バックエンドだけ** Rust / Rails に振り分ける必要がある。
- Litestream 前提の **SQLite 単一ライター** のため、同一テーブルへの Rust / Rails 同時 write は禁止（BC 単位切替）。

## 決定

**採用**: 既存のグローバル HTTPS ロードバランサ + **URL map の `pathRules` / `routeRules`** で、**別 Cloud Run サービス 2 本**（`agrr-server` Rust / 現行 Rails）にパス単位で振る。

| 項目 | 内容 |
|------|------|
| パブリックホスト | `agrr.net`（必要なら `www.agrr.net` も同一 map） |
| Rust 向けプレフィックス（終着・切替対象の枠） | `/api/*`、 `/cable`、 `/auth/*` |
| 未移行の既定 | **禁止（フォールバックなし）** — 未実装パスは `agrr-server` が **501** `api_not_migrated`。Rails `defaultService` で API を受けない |
| 切替単位 | **BC / ルート群** — URL map に **Rust 向け**ルールを追加。移行完了後は `/api/*` `/cable` `/auth/*` をすべて `rust-backend` へ |
| SPA 静的 | 現行どおり **GCS + CDN**（変更なし） |
| OAuth Console | **変更不要**（ホスト・パス維持） |

### バックエンド（移行期）

| バックエンド（論理名） | 実体 | 役割 |
|------------------------|------|------|
| `frontend-backend` | GCS バケット（CDN） | `*.js` / `*.css` / SPA fallback |
| `rails-backend` | 現行 Cloud Run（Rails） | **廃止予定** — 本番カットオーバー後はトラフィック 0。開発も `AGRR_RUST_API=1` で API は Rust のみ |
| `rust-backend` | Cloud Run（`agrr-server`、[`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server)） | **全 API** `/api/*`・`/cable`・`/auth/*`・`/up`（起動: [`start_agrr_server.sh`](../../../scripts/start_agrr_server.sh)） |

P7 完了後は `rails-backend` サービス削除、Rust 単体 + 静的のみ。

### パス振分（正）

**終着で Rust が受けるプレフィックス**（ユーザー可視 URL は不変）:

| プレフィックス | 用途 | 備考 |
|----------------|------|------|
| `/api/*` | JSON API | 切替は **BC ごと**（例: 先に `/api/v1/auth/*`、次に `public_plans` 群）。未移行パスは map にルールを置かず Rails が受ける |
| `/cable` | ActionCable ワイヤ互換 WS | locale 省略形（`defaults: { locale: "ja" }`）。`/{locale}/cable` を使うクライアントがあれば同ルールを追加 |
| `/auth/*` | OAuth・セッション | **`POST /auth/google_oauth2`**（OmniAuth・locale なし）を含む。`/{locale}/auth/login` 等は `/{locale}/auth/*` ルールを別途 |

**Rails に残す（移行期の代表）**:

| パス | 理由 |
|------|------|
| `/up` | 現行ヘルスチェック（Cloud Run / 監視）。Rust 側にも同実装後、監視を Rust に寄せてから切替 |
| `/rails/*` | ActiveStorage 等（ActiveStorage 削除後もアセットパイプラインがあれば維持） |
| 未移行の `/api/v1/...` | 該当 BC の R4 GREEN まで map に Rust ルールを追加しない |
| `/{locale}/undo_deletion` 等 | HTML マスタ廃止に伴い縮小。削除 undo は Angular 化 |

**内部向け**（Rust クリティカルパス）: `/api/v1/internal/*` は `/api/*` の一部。Scheduler は引き続き **同一ホスト** `POST https://agrr.net/api/v1/internal/jobs/trigger_weather_update`（切替後は rust-backend）。

### 切替手順（1 BC）

1. `agrr-server` + adapter + R1 パリティ + **R4 GREEN**
2. 単一ライター確認（当該 BC の write は Rust のみ）
3. URL map に **より具体的な** `pathRules` を追加（既存 Rails ルールより優先）
4. `gcloud compute url-maps validate` → `import`
5. 契約テスト・本番スモーク（OAuth / WS / 対象 API）

### 開発環境

| 環境 | 振分 |
|------|------|
| `docker compose` | **nginx または Caddy 1 台**で本番と同型のパス振分（`localhost:3000` → Rust :8080 / Rails :3000）。OAuth callback URL は `http://localhost:3000/auth/google_oauth2/callback` のまま |
| 単体 Rust のみ | `run-test-rust-domain.sh` / contract テスト — map 不要 |

本番 map の正は GCP 上の `agrr-frontend-url-map-simple`（または後継名）。export / validate / import は [load-balancer-update スキル](../../../.cursor/skills/load-balancer-update/SKILL.md)。

### 例: pathRules のイメージ（抜粋・優先度は実 map に合わせる）

```yaml
# 新規ルールは既存 SPA / 静的ルールより下、defaultService より上の順で挿入
pathRules:
  # 例: OAuth を最初に Rust へ（クリティカルパス 1）
  - paths: ["/auth/google_oauth2", "/auth/google_oauth2/*"]
    service: rust-backend
  - paths: ["/auth/*"]
    service: rust-backend
  # 例: BC 単位 API（移行済みのプレフィックスのみ列挙）
  - paths: ["/api/v1/auth/*"]
    service: rust-backend
  - paths: ["/cable", "/cable/*"]
    service: rust-backend
defaultService: rails-backend
```

**注意**: 上記は**全 `/api/*` を一括 Rust にしない**例。終着直前に残存 Rails API が無ければ `/api/*` 単一ルールでよい。

## 却下した案

| 案 | 理由 |
|----|------|
| **同一 Cloud Run コンテナ内**で nginx / Axum が Rails にリバースプロキシ | デプロイ単位が結合、スケール・障害ドメイン共有、P7 の Rails 廃止が遅れる |
| **`api.agrr.net` サブドメイン** | Cookie / CORS / WS / OAuth Console の全面変更（[PROVISIONAL-STACK](./PROVISIONAL-STACK.md) で却下済み） |
| **Big Bang**（初日から `/api/*` 全振り Rust） | 契約・単一ライター違反リスク。BC 単位の map 追加のみ |
| **FFI / 同一プロセスで Ruby Interactor 委譲** | [lib-domain-rust ARCHITECTURE](../lib-domain-rust/ARCHITECTURE.md) で非採用 |

## 影響

- 本番 URL map 切替の残作業: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)。
- インフラ変更は **ルート切替 PR と同じリリース**で validate → import（ロールバックは map を戻す）。
- 監視: `/up` の参照先を切替ごとに確認。

## 参照

- クリティカルパス順: [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) `critical_path`
- OAuth 案 A: [PROVISIONAL-STACK.md — OAuth](./PROVISIONAL-STACK.md#oauth-コールバック-url確定--2026-05-29案-a)
