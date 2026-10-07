# AGRR Masters API — はじめ方（スキル作者向け）

このページは [OpenAPI 3 仕様](./openapi.yaml) のクイックスタートです。MCP サーバー実装例は [`tools/agrr-mcp/README.md`](../../tools/agrr-mcp/README.md) を参照してください。

## 1. API キーを取得する

1. [AGRR](https://agrr.net) に Google アカウントでログインする
2. ナビゲーション **その他 → APIキー管理**（`/api-keys`）を開く
3. **APIキーを生成** をクリックする（再発行は **APIキーを再生成**）

キーは一度だけ画面に表示されます。安全な場所に保存してください。

プログラムからキーを発行する場合（ブラウザセッション必須）:

```http
POST /api/v1/api_keys/generate
Cookie: session_id=...
```

レスポンス: `{ "api_key": "..." }`

## 2. 認証

すべての Masters エンドポイントは **API キー** または **ログインセッション Cookie** が必要です。サーバー間連携では API キーを使います（**API キーは読み取り専用です。§3**）。

| 方式 | 例 |
|------|-----|
| Bearer | `Authorization: Bearer <api_key>` |
| ヘッダー | `x-api-key: <api_key>` |
| クエリ（非推奨） | `?api_key=<api_key>` |

## 3. スコープ

**API キーは読み取り専用です。書き込みはログインセッション（ブラウザ／画面）経由のみ可能です。**

API キーごとにスコープを保存し、Masters API（`/api/v1/masters/*`）で強制します。API キーが持つスコープは `masters:read` だけです。

| 操作 | API キー（`masters:read`） | ログインセッション |
|------|---------------------------|--------------------|
| `GET` / `HEAD`（一覧・詳細） | 可 | 可 |
| `setup_proposal?mode=dry_run`（検証のみ） | 可 | 可 |
| `POST` / `PUT` / `PATCH` / `DELETE`（作成・更新・削除） | 不可（HTTP 403） | 可 |
| `setup_proposal?mode=apply`（永続化） | 不可（HTTP 403） | 可 |

- 生成・再生成したキーは **常に `masters:read` のみ**です。
- API キーに書き込みスコープ（`masters:write`）を付与することはできません。付与する画面・API・申請手続きも提供しません。
- 書き込み（`setup_proposal?mode=apply` を含む）は、ログイン後の画面で行ってください。作物の提案 JSON は、作物の詳細・編集画面の **提案 JSON をインポート** から適用できます。
- 再発行（**APIキーを再生成**）すると、スコープは `masters:read` になります。
- スコープ導入前（V15 以前）に発行されたキーも、`masters:read` のみに揃えました。書き込みはログインセッション経由で行ってください。

書き込み系のリクエストを API キーで送ったときのレスポンス:

```json
{ "errors": ["forbidden"], "error_code": "insufficient_scope" }
```

## 4. レート制限

`/api/v1/masters/*` に per-user の分単位レート制限があります（本番の既定値）。

| 区分 | 対象 | 既定（リクエスト/分） |
|------|------|----------------------|
| 読み取り | `GET` / `HEAD` | 120 |
| dry_run | `POST .../setup_proposal?mode=dry_run` | 30 |
| 書き込み | `POST` / `PUT` / `PATCH` / `DELETE`（apply 以外） | 60 |
| apply（セッションのみ） | `POST .../setup_proposal?mode=apply` | 5 |

超過時は **HTTP 429** と **`Retry-After`** ヘッダー（秒）が返ります。

```json
{ "errors": ["rate_limit"] }
```

## 5. 典型的なフロー（setup_proposal）

外部スキルが作物マスタを提案するときの推奨手順（API キーは読み取り専用のため、適用はログイン後の画面で行います）:

1. `GET /api/v1/masters/crops` で対象作物 ID を確認（API キー）
2. `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run` で提案 JSON を検証（API キー）
3. `valid: true` なら、`normalized` の JSON を利用者に渡し、画面の **提案 JSON をインポート**（`/crops/{crop_id}/setup_proposal`）で適用（ログインセッション）
4. 適用後、必要に応じて `GET .../crop_stages` や `.../task_schedule_blueprints` で結果を確認（API キー）

### dry_run 例

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $AGRR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://agrr.net/api/v1/masters/crops/42/setup_proposal?mode=dry_run" \
  -d @proposal.json
```

## 6. 関連ドキュメント

- [OpenAPI 3 — Masters API](./openapi.yaml)
- [setup_proposal スキーマ詳細](./setup_proposal-openapi-snippet.yaml)（レガシー snippet・本体は openapi.yaml に統合）
- [agrr-mcp 公式 MCP サーバー](../../tools/agrr-mcp/README.md)

## 7. ベース URL

| 環境 | URL |
|------|-----|
| 本番 | `https://agrr.net` |
| ローカル Docker | `http://127.0.0.1:3000`（strangler-proxy 経由） |
