# ADR-002: Organization モデル（B2B マルチテナンシー土台）

## Status

Accepted (2026-08-06)

親エピック: [#604](https://github.com/rick-chick/agrr/issues/604)（Organization モデル — B2B 法人・チーム共有の土台）。

## Context

AGRR は現状 **ユーザー単位のテナント分離** のみを持つ。農場・作物・計画などの所有リソースは `user_id` でスコープされ、ドメインポリシー（例: `farm_policy.rs`）も `user_id` 一致または `admin` / `is_reference` で判定する。

| 課題 | 内容 |
|------|------|
| 法人利用不可 | 1 組織・複数ユーザー・委任管理（管理者がメンバー招待、組織単位で計画共有）のモデルがない |
| 後付けコスト | エンタープライズ SSO / SCIM を後から足す場合、Organization なしでは全面リファクタが必要（CIAM Compass / WorkOS 等の B2B SaaS パターンと非整合） |
| クォータ境界 | Farm / Crop 作成上限は `user_id` 単位（`FarmCreateLimitPolicy` / `CropCreateLimitPolicy`）。法人契約では組織単位の制限が自然 |

現状の参照実装:

| 領域 | 根拠 |
|------|------|
| スキーマ | `crates/agrr-migrate/migrations/schema/V1__baseline.sql` — `farms.user_id NOT NULL` 等 |
| アクセス制御 | `crates/agrr-domain/src/shared/policies/farm_policy.rs` — `user_id == Some(user.id)` |
| 一覧フィルタ | `crates/agrr-adapters-sqlite/src/shared/reference_index.rs` — `user_id = ?` |
| 認証 | `crates/agrr-server/src/session_auth.rs` — セッション / API キー → `User` |

**Organization**（Schema.org JSON-LD の `Organization` 型）とは無関係。本 ADR の Organization は **B2B テナント（法人・チーム）** を指す。

## Decision

### 1. Organization を第一級オブジェクトとする

- `organizations` テーブル: テナントのルート（名称、slug、設定メタデータ）
- `organization_memberships` テーブル: ユーザーと組織の **多対多** + ロール（RBAC のフック）
- 所有リソース（Tier 1）に `organization_id` を付与し、テナント境界の主キーとする

詳細なテーブル定義・移行方針は [`organization-data-model.md`](../design/organization-data-model.md) を参照。

### 2. 個人ユーザー = 個人 Organization（移行戦略）

既存の個人農家ユーザーには **1:1 の personal org** を自動作成する。

1. バックフィル: 各 `users` 行に対し `organizations` + `organization_memberships`（role: `owner`）を作成
2. Tier 1 リソースの `organization_id` を、当該 `user_id` の personal org に設定
3. 移行期間中は `user_id` 列を残し、ポリシーは `organization_id` 優先へ段階的に切り替え
4. 参照マスタ（`is_reference = 1`, `user_id IS NULL`）は **グローバル** のまま変更しない

### 3. Organization の責務境界（設定のみ・フェーズ 1 以降で拡張）

| 責務 | 設定境界（Organization レベル） | フェーズ |
|------|--------------------------------|----------|
| **RBAC** | メンバーシップロール（`owner` / `admin` / `member`） | 1 |
| **リソース共有** | 同一 `organization_id` 内の Farm / Crop / Plan 共有 | 1 |
| **クォータ** | Farm / Crop 上限を org 単位に集約（personal org は現行と同等） | 2 |
| **SSO** | IdP 連携・ドメイン検証（SAML / OIDC） | 3+ |
| **SCIM** | ユーザー・グループプロビジョニング | 3+ |
| **監査** | org 単位の操作ログエクスポート | 3+ |

フェーズ 1 では **CRUD + membership + org スコープ付与** に限定する。SSO / SCIM はスキーマと API 形状を阻害しない設計に留め、実装は子 issue で後続。

### 4. アクセス制御の移行方針

ドメイン層（`crates/agrr-domain`）では:

1. **新規**: `OrganizationAccessPolicy`（仮称）— メンバーシップ + ロール + `organization_id` 一致
2. **既存ポリシー**: `FarmPolicy` 等は `organization_id` チェックを追加し、`user_id` 単独判定を段階的に縮小
3. **admin**: システム管理者は全 org を横断可能（現行 `user.admin` と同等）
4. **Clean Architecture**: 判断は Interactor + policy。Gateway は `organization_id` による狭い永続化クエリのみ

### 5. API 形状（フェーズ 1 概要）

| エンドポイント | 用途 |
|----------------|------|
| `GET/POST /api/v1/organizations` | 組織一覧・作成 |
| `GET/PATCH/DELETE /api/v1/organizations/{id}` | 組織詳細・更新・削除 |
| `GET/POST /api/v1/organizations/{id}/memberships` | メンバー一覧・追加 |
| `PATCH/DELETE /api/v1/organizations/{id}/memberships/{user_id}` | ロール変更・除名 |

認可: 操作者が当該 org の `owner` または `admin`（メンバー管理）であること。リソース CRUD は既存 Masters API に `organization_id` コンテキストを注入。

## Rejected alternatives

### A. `user_id` 共有のみ（組織テーブルなし）

複数ユーザーが同一 `user_id` を共有する案。監査・招待・ロール・SSO 連携が不可能で、セキュリティ上採用しない。

### B. `team_id` を各リソースに直接付与（membership なし）

組織とユーザーの多対多を表現できず、メンバー管理・ロール変更のたびに全リソース行を更新する必要がある。

### C. 全面 `organization_id` 即時切替（`user_id` 即削除）

既存 API・ポリシー・契約テストへの破壊的変更が大きい。移行期間中の二重キー（`user_id` + `organization_id`）を許容し段階的に縮小する。

## Consequences

### 影響を受けるコンポーネント

| 領域 | 対象 |
|------|------|
| マイグレーション | `crates/agrr-migrate/migrations/schema/V15__organizations.sql`（新規） |
| ドメイン | `agrr-domain` — `organization` コンテキスト新設、既存 `*_policy.rs` 拡張 |
| アダプター | `agrr-adapters-sqlite` — org gateway、Tier 1 テーブルの `organization_id` 列 |
| HTTP | `agrr-server` — Organization / Membership API、既存 Masters の org コンテキスト |
| フロント | org 切替 UI・コンテキスト（フェーズ 1 以降の子 issue） |
| 契約テスト | R4 — org スコープの認可・CRUD 振る舞い |

### 残すもの

- 参照マスタ（`is_reference = 1`）のグローバル公開
- `users` / `sessions` の認証モデル（org とは membership で接続）
- 気象データ等の共有インフラ（org 非スコープ）

## Migration phases

実装順はエピック [#604](https://github.com/rick-chick/agrr/issues/604) の子 issue に従う。起票後に issue 番号を本表へ追記する。

| フェーズ | Issue | 内容 |
|----------|-------|------|
| 1. 方針固定 | [#606](https://github.com/rick-chick/agrr/issues/606) | ADR-002 Accepted 確定 |
| 2. スキーマ | [#607](https://github.com/rick-chick/agrr/issues/607) | `organizations` / `organization_memberships` + Tier 1 `organization_id` |
| 3. ドメイン | [#608](https://github.com/rick-chick/agrr/issues/608) | Organization entity / gateway / membership policy |
| 4. API | [#609](https://github.com/rick-chick/agrr/issues/609) | Organization CRUD API |
| 4b. API | [#610](https://github.com/rick-chick/agrr/issues/610) | organization_memberships API |
| 5. バックフィル | [#611](https://github.com/rick-chick/agrr/issues/611) | personal org 作成 + 既存データ移行 |
| 6. ポリシー移行 | [#612](https://github.com/rick-chick/agrr/issues/612) | Farm / Crop / Plan の org スコープ認可 |

完了条件（エピック全体）は [#604](https://github.com/rick-chick/agrr/issues/604) を参照。

## References

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — レイヤ境界・Interactor / Gateway 規約
- [`organization-data-model.md`](../design/organization-data-model.md) — テーブル定義・Tier 分類
- `crates/agrr-domain/src/shared/policies/farm_policy.rs`
- `crates/agrr-migrate/migrations/schema/V1__baseline.sql`
- [WorkOS — Multi-tenant SaaS architecture](https://workos.com/blog/what-is-multi-tenancy)（B2B パターン参考）
- 親エピック [#604](https://github.com/rick-chick/agrr/issues/604)
