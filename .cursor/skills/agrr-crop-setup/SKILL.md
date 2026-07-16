---
name: agrr-crop-setup
description: >-
  External skill sample for crop master setup via official AGRR MCP tools.
  Reference crop lookup → LLM proposal → dry_run validation → user confirm → apply.
  Use when setting up crop stages, agricultural tasks, and task schedule blueprints
  for a user crop via setup_proposal (not ai_create or regenerate).
disable-model-invocation: false
---

# AGRR Crop Setup（外部スキルサンプル）

作物マスタ（生育ステージ・作業・作業スケジュール青写真）を **公式 MCP** 経由で `setup_proposal` に投入する手順。

## 前提

- MCP サーバー [`tools/agrr-mcp`](../../../tools/agrr-mcp/README.md) が Cursor に接続済み
- 環境変数 `AGRR_API_KEY` / `AGRR_API_BASE_URL` が MCP 設定に渡されている
- 対象は **ユーザー所有の作物**（`is_reference: false`）。リファレンス作物は参照のみ

## 入力（ユーザーから取得）

| 項目 | 例 |
|------|-----|
| 作物名 | トマト |
| 品種 | 桃太郎 |
| region | `jp` / `us` / `in` |
| 栽培型 | 露地 / ハウス 等（提案 JSON のステージ名・作業に反映） |

## 手順

1. **リファレンス作物を参照** — MCP `list_reference_crops`（`region` で絞る）→ `get_crop_detail` でステージ・作業の構成を読む
2. **LLM で提案 JSON を組み立て** — スキーマは [`docs/api/setup_proposal-openapi-snippet.yaml`](../../../docs/api/setup_proposal-openapi-snippet.yaml) に従う。`agricultural_tasks[].ref` と `task_schedule_blueprints[].agricultural_task_ref` を整合させる
3. **dry_run** — MCP `propose_crop_setup`（`crop_id` + `proposal`）。`valid: false` なら `errors` を修正して再試行
4. **ユーザー確認** — `normalized` の内容を提示し、適用の明示的な承認を得る
5. **apply** — MCP `apply_crop_setup`（同一 `proposal`）。成功後 `result.stage_ids` / `blueprint_ids` を報告

## 禁止

- `POST /api/v1/crops/ai_create` および肥料・害虫の `ai_create` / `ai_update`
- `POST .../task_schedule_blueprints/regenerate`
- agrr デーモン（最適化・気象・GDD 計算）の直叩き — マスタ投入には不要
- MCP / スキル内でのビジネスルール複製（検証は AGRR API に委ねる）

## 参照

- ADR: [`docs/adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md`](../../../docs/adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md)
- MCP README: [`tools/agrr-mcp/README.md`](../../../tools/agrr-mcp/README.md)
