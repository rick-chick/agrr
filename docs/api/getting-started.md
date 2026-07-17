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

すべての Masters エンドポイントは **API キー** または **ログインセッション Cookie** が必要です。サーバー間連携では API キーを使います。

| 方式 | 例 |
|------|-----|
| Bearer | `Authorization: Bearer <api_key>` |
| ヘッダー | `x-api-key: <api_key>` |
| クエリ（非推奨） | `?api_key=<api_key>` |

## 3. スコープ（将来の tier 用）

現時点ではキーごとのスコープ列は DB に保存していません。ドキュメント上の概念として次を使います。

| スコープ | 操作 |
|----------|------|
| `masters:read` | `GET` / `HEAD`（一覧・詳細・`setup_proposal?mode=dry_run` を含む読み取り相当） |
| `masters:write` | 作成・更新・削除・`setup_proposal?mode=apply` |

発行されたキーは現状 **読み取りと書き込みの両方** が可能です。将来の課金 tier でスコープを分離する予定です。

## 4. レート制限

`/api/v1/masters/*` に per-user の分単位レート制限があります（本番の既定値）。

| 区分 | 対象 | 既定（リクエスト/分） |
|------|------|----------------------|
| 読み取り | `GET` / `HEAD` | 120 |
| dry_run | `POST .../setup_proposal?mode=dry_run` | 30 |
| 書き込み | `POST` / `PUT` / `PATCH` / `DELETE`（apply 以外） | 60 |
| apply | `POST .../setup_proposal?mode=apply` | 5 |

超過時は **HTTP 429** と **`Retry-After`** ヘッダー（秒）が返ります。

```json
{ "error": "rate_limit" }
```

## 5. 典型的なフロー（setup_proposal）

外部スキルが作物マスタを提案するときの推奨手順:

1. `GET /api/v1/masters/crops` で対象作物 ID を確認
2. `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run` で提案 JSON を検証
3. `valid: true` なら `mode=apply` で永続化
4. 必要に応じて `GET .../crop_stages` や `.../task_schedule_blueprints` で結果を確認

### dry_run 例

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $AGRR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://agrr.net/api/v1/masters/crops/42/setup_proposal?mode=dry_run" \
  -d @proposal.json
```

### apply 例

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $AGRR_API_KEY" \
  -H "Content-Type: application/json" \
  "https://agrr.net/api/v1/masters/crops/42/setup_proposal?mode=apply" \
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
