# 内蔵生成 API の Sunset（移行ガイド）

本ページは [ADR-001](../adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md) に基づき、AGRR 内蔵の LLM 生成エンドポイントを廃止するための移行手順です。コード・ルートの**削除**は Sunset 日（**2026-10-18**）以降の [#323](https://github.com/rick-chick/agrr/issues/323) で行います。

## 対象エンドポイント

| 廃止対象 | 代替 |
|----------|------|
| `POST /api/v1/crops/ai_create` | 作物を `POST /api/v1/masters/crops` で作成し、`setup_proposal` で投入 |
| `POST /api/v1/fertilizes/ai_create` | `POST /api/v1/masters/fertilizes`（手動 or 外部自動化） |
| `POST /api/v1/fertilizes/{id}/ai_update` | `PATCH /api/v1/masters/fertilizes/{id}` |
| `POST /api/v1/pests/ai_create` | `POST /api/v1/masters/pests` |
| `POST /api/v1/pests/{id}/ai_update` | `PATCH /api/v1/masters/pests/{id}` |
| `POST /api/v1/masters/crops/{crop_id}/task_schedule_blueprints/regenerate` | `setup_proposal` に `task_schedule_blueprints` を含める |

## 応答ヘッダ（RFC 9745）

Sunset 期間中、上記エンドポイントは従来どおり応答しますが、次のヘッダと JSON フィールドが付きます。

| ヘッダ / フィールド | 値の例 |
|---------------------|--------|
| `Deprecation` | `@2026-07-18` |
| `Sunset` | `Sat, 18 Oct 2026 00:00:00 GMT` |
| `deprecated` (body) | `true` |
| `deprecation.sunset` (body) | `2026-10-18` |
| `deprecation.alternative` (body) | エンドポイントごとの代替経路 |
| `deprecation.migration_guide` (body) | `/docs/api/builtin-generation-sunset.md` |

## 作物マスタ（推奨経路）

### 1. 外部スキル / MCP で提案 JSON を生成

- 公式 MCP: [`tools/agrr-mcp/README.md`](../../tools/agrr-mcp/README.md)
- Cursor スキル例: [`.cursor/skills/agrr-crop-setup/SKILL.md`](../../.cursor/skills/agrr-crop-setup/SKILL.md)

### 2. `setup_proposal` で検証・投入

```http
POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run
Authorization: Bearer <api_key>
Content-Type: application/json

{ "stages": [...], "agricultural_tasks": [...], "task_schedule_blueprints": [...] }
```

- `dry_run` — 正規化結果と validation errors のみ（永続化なし）
- `apply` — 検証通過時にトランザクションで一括永続化

詳細は [getting-started.md](./getting-started.md) §5 を参照。

### 3. UI からインポート

ブラウザでは作物詳細・編集画面の **提案 JSON をインポート**（`/crops/{id}/setup_proposal`）から同じ `setup_proposal` API を呼び出せます。

## 作業スケジュール青写真の再生成

`regenerate` の代わりに、提案 JSON の `task_schedule_blueprints` 配列を `setup_proposal` に渡します。既存の青写真は `apply` 時に置き換えられます（`dry_run` で事前確認してください）。

## 肥料・害虫マスタ

内蔵 `ai_create` / `ai_update` には公式の一括投入 API はありません。Masters CRUD で手動登録するか、外部スクリプトで `POST` / `PATCH` を呼び出してください。

## タイムライン

| 日付 | 内容 |
|------|------|
| 2026-07-18 | Sunset 宣言（本ガイド・Deprecation/Sunset ヘッダ） |
| 2026-10-18 | エンドポイント削除（[#323](https://github.com/rick-chick/agrr/issues/323)） |

## 参照

- [ADR-001](../adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md)
- [OpenAPI](./openapi.yaml) — `setup_proposal`
- [getting-started.md](./getting-started.md)
