# ADR-002: Organization モデル（B2B マルチテナンシー土台）

## Status

Accepted (2026-08-06)

Plan の組織共有、および Farm / Crop の**編集**の組織共有は [ADR-003](ADR-003-organization-sharing-owner-only.md) で撤回された（ADR-002 の Status は Accepted のまま）。

親エピック: [#604](https://github.com/rick-chick/agrr/issues/604)（Organization モデル — B2B 法人・チーム共有の土台）。

## Context

AGRR は起票時点（2026-08-06）で **ユーザー単位のテナント分離** のみを持っていた。農場・作物・計画などの所有リソースは `user_id` でスコープされ、ドメインポリシー（例: `farm_policy.rs`）も `user_id` 一致または `admin` / `is_reference` で判定していた。現在は organization 単位のアクセス制御が併存する（下記「実装状況」）。

| 課題 | 内容 |
|------|------|
| 法人利用不可 | 1 組織・複数ユーザー・委任管理（管理者がメンバー招待、組織単位で計画共有）のモデルがない |
| 後付けコスト | エンタープライズ SSO / SCIM を後から足す場合、Organization なしでは全面リファクタが必要（CIAM Compass / WorkOS 等の B2B SaaS パターンと非整合） |
| クォータ境界 | （起票時点）Farm / Crop 作成上限は `user_id` 単位（`FarmCreateLimitPolicy` / `crop_create_limit_policy`）。法人契約では組織単位の制限が自然（現在は組織単位に統一済み。下記「実装状況」） |

起票時点の参照実装:

| 領域 | 根拠 |
|------|------|
| スキーマ | `crates/agrr-migrate/migrations/schema/V1__baseline.sql` — `farms.user_id NOT NULL` 等 |
| アクセス制御 | `crates/agrr-domain/src/shared/policies/farm_policy.rs` — `user_id == Some(user.id)` |
| 一覧フィルタ | `crates/agrr-adapters-sqlite/src/shared/reference_index.rs` — `user_id = ?` |
| 認証 | `crates/agrr-server/src/session_auth.rs` — セッション / API キー → `User` |

実装状況（2026-10-07 時点）:

| 領域 | 根拠 |
|------|------|
| 一覧フィルタ | `reference_index.rs` — org 所属時は `organization_id IN (...)`、未所属時は `user_id` |
| Farm / Crop 認可 | `ReferenceRecordAccessFilter` — **閲覧**: policy または org メンバーシップ。**編集**: policy（所有者・admin）のみ（[ADR-003](ADR-003-organization-sharing-owner-only.md)） |
| Plan 認可 | 所有者のみ（組織スコープなし。[ADR-003](ADR-003-organization-sharing-owner-only.md)） |
| クォータ | 全経路が組織単位で、メンバー全員で枠を共有。Masters / AI upsert / plan-save は `organization_id` かつ `is_reference = 0` で数える |

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
| **クォータ** | Farm / Crop 上限を org 単位に集約。組織の全メンバーで枠を共有（personal org は現行と同等）。契約プラン別上限は未定義 | 1（集計単位）/ 2（プラン別上限） |

Plan は組織で共有しない。Farm / Crop の**編集**も組織メンバーシップでは許可しない（閲覧・枠は [ADR-003](ADR-003-organization-sharing-owner-only.md)）。
| **SSO** | IdP 連携・ドメイン検証（SAML / OIDC） | 3+ |
| **SCIM** | ユーザー・グループプロビジョニング | 3+ |
| **監査** | org 単位の操作ログエクスポート | 3+ |

フェーズ 1 では **CRUD + membership + org スコープ付与** に限定する。SSO / SCIM はスキーマと API 形状を阻害しない設計に留め、実装は子 issue で後続。

### 4. アクセス制御の移行方針

ドメイン層（`crates/agrr-domain`）では:

1. **新規**: `OrganizationAccessPolicy`（`crates/agrr-domain/src/organization/policies/organization_access_policy.rs`）— メンバーシップ + ロール + `organization_id` 一致
2. **既存ポリシー**: Farm / Crop 等の org 対応は `ReferenceRecordAccessFilter`（`reference_record_access_filter.rs`）を介する。`user_id` 単独判定は policy 側に残る。**編集**は組織メンバーシップでは許可しない（[ADR-003](ADR-003-organization-sharing-owner-only.md)）
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
| マイグレーション | `crates/agrr-migrate/migrations/schema/V16__organizations.sql` |
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

実装順はエピック [#604](https://github.com/rick-chick/agrr/issues/604) の子 issue に従う。

| ステップ | Issue | 内容 | 状態 |
|----------|-------|------|------|
| 1. 方針固定 | [#606](https://github.com/rick-chick/agrr/issues/606) | ADR-002 Accepted 確定 | 完了（2026-08-06） |
| 2. スキーマ | [#607](https://github.com/rick-chick/agrr/issues/607) | `organizations` / `organization_memberships` + Tier 1 `organization_id` | 完了（2026-08-06） |
| 3. ドメイン | [#608](https://github.com/rick-chick/agrr/issues/608) | Organization entity / gateway / membership policy | 完了（2026-08-06） |
| 4. API | [#609](https://github.com/rick-chick/agrr/issues/609) | Organization CRUD API | 完了（2026-08-06） |
| 4b. API | [#610](https://github.com/rick-chick/agrr/issues/610) | organization_memberships API | 完了（2026-08-06） |
| 5. バックフィル | [#611](https://github.com/rick-chick/agrr/issues/611) | personal org 作成 + 既存データ移行 | 完了（2026-08-06） |
| 6. ポリシー移行 | [#612](https://github.com/rick-chick/agrr/issues/612) | Farm / Crop / Plan の org スコープ認可（Plan の組織共有と Farm / Crop の組織編集は [ADR-003](ADR-003-organization-sharing-owner-only.md) で撤回） | 完了（2026-08-06） |

完了条件（エピック全体）は [#604](https://github.com/rick-chick/agrr/issues/604) を参照。

## References

- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — レイヤ境界・Interactor / Gateway 規約
- [`organization-data-model.md`](../design/organization-data-model.md) — テーブル定義・Tier 分類
- `crates/agrr-domain/src/shared/policies/farm_policy.rs`
- `crates/agrr-migrate/migrations/schema/V1__baseline.sql`
- [WorkOS — Multi-tenant SaaS architecture](https://workos.com/blog/what-is-multi-tenancy)（B2B パターン参考）
- 親エピック [#604](https://github.com/rick-chick/agrr/issues/604)
