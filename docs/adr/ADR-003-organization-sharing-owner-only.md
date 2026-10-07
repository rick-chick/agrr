# ADR-003: Organization 共有の縮小（Plan は所有者のみ、Farm / Crop の編集は所有者のみ）

## Status

Accepted (2026-10-07)

親: [ADR-002: Organization モデル（B2B マルチテナンシー土台）](ADR-002-organization-multi-tenancy.md) — エピック [#604](https://github.com/rick-chick/agrr/issues/604)。実装: [#1348](https://github.com/rick-chick/agrr/issues/1348)（Plan）、[#1352](https://github.com/rick-chick/agrr/issues/1352)（Farm / Crop 編集）、[#1347](https://github.com/rick-chick/agrr/issues/1347) / [#1352](https://github.com/rick-chick/agrr/issues/1352)（組織単位クォータ・plan-save）。

## Context

ADR-002 はフェーズ 1 で「同一 `organization_id` 内の Farm / Crop / Plan 共有」を Decision に含めた（ADR-002 §3）。#612 により組織スコープ認可が入ったが、過剰許可の是正として次が確定した（[`10-authorization-consistency.md`](../spec-defects/10-authorization-consistency.md) §0）。

| 決定 | 内容 |
|------|------|
| Plan | 組織メンバーは他メンバー所有 Plan とその配下を**閲覧も編集もできない**。Plan 系は**所有者のみ** |
| Farm / Crop の編集 | 更新・削除、ネスト編集、気象取得の起動、Plan への Crop 追加、AI upsert も**所有者のみ**（`organization_member_edit_allowed` は Farm / Crop で `false`） |
| Farm / Crop の枠 | 非参照 Farm 4・Crop 20 は**組織単位**で、メンバー全員が同じ枠を共有（[#1352](https://github.com/rick-chick/agrr/issues/1352) / [#1347](https://github.com/rick-chick/agrr/issues/1347)） |
| Farm / Crop の一覧 | Masters 一覧は組織スコープ（`reference_index.rs` の `organization_id IN (...)`）。閲覧範囲の将来変更は未決（10 §3.1 P14） |

ADR-002 の Decision 本文（`:54` リソース共有、`:67` の `user_id` 単独判定の段階的縮小）は、上記と**意図が異なる**。履歴を混ぜないため本 ADR で撤回・置き換える。

## Decision

### 1. Plan は組織で共有しない

`cultivation_plans` は Tier 1 で `organization_id` 列を持つが、認可は**作成者（`user_id`）一致**のみ。組織スコープ判定は Plan 系から使わない。

### 2. Farm / Crop の編集は所有者のみ、枠と一覧は組織単位

- **編集**: `FarmPolicy` / `CropPolicy` の `edit_allowed` と、`ReferenceRecordAccessFilter`（Farm / Crop は `organization_member_edit_allowed() == false`）で所有者（と `admin`）のみ。
- **枠**: 作成先組織の非参照件数（`organization_id = ?` かつ `is_reference = 0`）。Masters・Crop AI upsert・公開計画保存（plan-save）で同じ。
- **一覧・詳細の閲覧**: 組織メンバーシップ経由の `view_allows` は現状維持（P14 未決のため、将来の変更は別 ADR）。

### 3. 維持するもの

Organization / Membership モデルと API、`organization_member_access` / `member_organization_ids`、`cultivation_plans.organization_id` 列（スキーマ・backfill）、Farm / Crop の `organization_id` と組織単位クォータ。

### 4. ADR-002 との関係

ADR-002 は Accepted のまま。Plan の組織共有および Farm / Crop の**編集**の組織共有は本 ADR で撤回する。クォータの org 単位集約（ADR-002 §3 のクォータ行）は有効。

## 組織共有の再開条件（未決定の再開条件）

B2B で組織共有を**将来**再開する場合は、次をすべて満たすことを前提とする。本 ADR は再開を実装しない。詳細設計は再開時に行う。

1. 共有対象の Plan を所有者が明示する仕様がある。**既存 Plan を `organization_id` の backfill だけで自動共有しない**。
2. 閲覧と編集を分け、ロールまたは共有時の権限指定がある。`organization_member_access` の一律許可（役割を見ない）に戻さない。
3. Plan 配下の全経路と Farm / Crop の編集経路が同じ判定に通る（経路ごとの方式不一致を作らない）。
4. personal org へのメンバー追加ガードが決まっている。
5. R4 契約テストで共有 Plan の閲覧・編集の成否を経路ごとに固定する。

## Consequences

| 領域 | 内容 |
|------|------|
| ドメイン | Plan 系は org スコープを外す。Farm / Crop は `organization_member_edit_allowed: false` |
| 文書 | ADR-002 に参照追記、`organization-data-model.md` のロール表・Plan 行を更新 |
| 将来 | 再開時は新 ADR または本 ADR の Superseded で判断履歴を残す |

## References

- [ADR-002](ADR-002-organization-multi-tenancy.md)
- [`organization-data-model.md`](../design/organization-data-model.md)
- [`10-authorization-consistency.md`](../spec-defects/10-authorization-consistency.md) §3.3
- [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — Resource Limits
