# ADR-001: 生成は外・計算は agrr デーモン（内蔵 AI 廃止方針）

## Status

Accepted (2026-07-16)

親イニシアチブ: [#316](https://github.com/rick-chick/agrr/issues/316)（外部スキル＋`setup_proposal`）。

## Context

作物マスタ（生育ステージ・作業テンプレ・作業スケジュール青写真）の作成は手間が大きく、LLM による提案で省力化できる。一方、AGRR 本体に LLM 生成を内蔵すると次の負担が本体に載る。

| 課題 | 内容 |
|------|------|
| モデル更新 | プロバイダ・モデル世代の追従をアプリリリースに結びつける |
| 課金・コスト | 生成トークン課金が本体の運用コストになる |
| 品質責任 | 提案の正確性・地域適合性の責任が AGRR 製品に集中する |
| 二重経路 | 内蔵生成と外部スキルが併存すると、検証・廃止・ドキュメントが技術負債になる |

現状、生成は agrr デーモン経由の内蔵経路が存在する。

| 経路 | 根拠 |
|------|------|
| 作物・肥料・害虫の AI 作成 | `crates/agrr-server/src/ai_api.rs` — `POST /api/v1/crops/ai_create` 等 |
| 作業スケジュール青写真の再生成 | `crates/agrr-server/src/masters_crop_task_schedule_blueprints.rs` — `POST .../task_schedule_blueprints/regenerate` |

agrr デーモンは GDD 進捗・最適化・気象予測など**農業計算**に適している。マスタ提案の**生成**をデーモンに載せ続けると、「計算エンジン」と「コンテンツ生成」の責務が混在する。

既存 Masters CRUD のみで外部スキルを運用する案もあるが、1 作物あたり 40 件超の API 呼び出し・途中失敗時の部分データ・`agricultural_task_id` の鶏卵問題が残る（[#316](https://github.com/rick-chick/agrr/issues/316) 参照）。

## Decision

### 1. 生成は外部スキルのみ

生育ステージ・作業マスタ・作業スケジュール青写真の**提案 JSON の生成**は、AGRR 外のスキル（MCP ツール・CLI・手動編集等）が担う。AGRR は検証・正規化・永続化・農業計算のみ行う。

### 2. 正規投入経路は `setup_proposal`

外部スキルが AGRR に投入する正規 API は次とする（実装は [#318](https://github.com/rick-chick/agrr/issues/318)）。

```
POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run|apply
```

- `dry_run` — 検証のみ。正規化後 JSON と validation errors を返す。
- `apply` — 検証通過時のみトランザクションで一括永続化。

### 3. agrr デーモンは計算のみ

agrr デーモンは GDD・最適化・気象・進捗など**計算**に限定する。マスタ提案の LLM 生成は呼ばない。

### 4. 内蔵生成 API は deprecated → 削除

次のエンドポイントは廃止対象とする。Sunset 宣言は [#322](https://github.com/rick-chick/agrr/issues/322)、コード・ルート削除は [#323](https://github.com/rick-chick/agrr/issues/323)。

| エンドポイント | モジュール |
|----------------|------------|
| `POST /api/v1/crops/ai_create` | `ai_api.rs` |
| `POST /api/v1/fertilizes/ai_create` | `ai_api.rs` |
| `POST /api/v1/fertilizes/{id}/ai_update` | `ai_api.rs` |
| `POST /api/v1/pests/ai_create` | `ai_api.rs` |
| `POST /api/v1/pests/{id}/ai_update` | `ai_api.rs` |
| `POST /api/v1/masters/crops/{crop_id}/task_schedule_blueprints/regenerate` | `masters_crop_task_schedule_blueprints.rs` |

代替: `setup_proposal` + 外部スキル（[#319](https://github.com/rick-chick/agrr/issues/319)）または UI インポート（[#321](https://github.com/rick-chick/agrr/issues/321)）。

## Rejected alternatives

### A. 既存 Masters CRUD のみでスキル運用

原子性がなく、作者・スキル間で投入順序や参照解決がばらつく。`setup_proposal` による一括検証・トランザクション投入を採用する。

### B. 内蔵 AI と外部スキルの併存

`ai_create` / `regenerate` を残したまま外部スキルを追加すると、二重経路・二重テスト・移行先の曖昧さが残る（[`no-convenience-tech-debt.mdc`](../../.cursor/rules/no-convenience-tech-debt.mdc) に反する）。併存は採用しない。

## Consequences

### 影響を受けるコンポーネント

| 領域 | 対象 |
|------|------|
| HTTP | `crates/agrr-server/src/ai_api.rs` |
| HTTP | `crates/agrr-server/src/masters_crop_task_schedule_blueprints.rs`（`regenerate`） |
| アダプター | 生成専用 `*AiQueryDaemonGateway`（`crates/agrr-adapters-agrr/src/`） |
| ドメイン | `CropAiCreateInteractor`、`CropRegenerateTaskScheduleBlueprintsInteractor` 等（HTTP 露出廃止後は削除候補） |
| フロント | 内蔵 `regenerate` / `ai_create` 呼び出しがあればインポート or 手動に差し替え（[#321](https://github.com/rick-chick/agrr/issues/321)） |

### 残すもの

- agrr デーモンの**計算**用ゲートウェイ（最適化、気象、GDD 進捗等）
- Masters CRUD + `setup_proposal`（[#318](https://github.com/rick-chick/agrr/issues/318)）

## Migration phases

実装順はエピック [#316](https://github.com/rick-chick/agrr/issues/316) に従う。

| フェーズ | Issue | 内容 |
|----------|-------|------|
| 1. 方針固定 | **#317**（本 ADR） | 生成は外・計算はデーモンを文書化 |
| 2. 正規 API | [#318](https://github.com/rick-chick/agrr/issues/318) | `setup_proposal`（`dry_run` / `apply`） |
| 3. スキル配布 | [#319](https://github.com/rick-chick/agrr/issues/319) | 公式 MCP + サンプルスキル |
| 4. API 商品化 | [#320](https://github.com/rick-chick/agrr/issues/320) | OpenAPI・API キー導線・レート制限 |
| 5. UI | [#321](https://github.com/rick-chick/agrr/issues/321) | 提案 JSON インポート（プレビュー → apply） |
| 6. Sunset | [#322](https://github.com/rick-chick/agrr/issues/322) | `Deprecation` / `Sunset` ヘッダ・移行ガイド |
| 7. 削除 | [#323](https://github.com/rick-chick/agrr/issues/323) | 内蔵生成コード・エンドポイント削除（Sunset 経過後） |

完了条件（エピック全体）は [#316](https://github.com/rick-chick/agrr/issues/316) を参照。

## References

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — JSON API チェックリスト（`ai_create` も層分離の対象。本 ADR は生成の**所在**を決める）
- [`no-convenience-tech-debt.mdc`](../../.cursor/rules/no-convenience-tech-debt.mdc)
- `crates/agrr-server/src/ai_api.rs`
- `crates/agrr-server/src/masters_crop_task_schedule_blueprints.rs`
