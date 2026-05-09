# Gateway アダプターとポリシー境界（バックエンド横断）

## 目的

`ARCHITECTURE.md` の **Gateway boundary (presentation-agnostic)** に沿い、マスタ系・永続化アダプターと `lib/domain` の責務分担を固定する。Angular ↔ API の個別機能契約（`crop-contract.md` 等）とは別の **レイヤー運用契約**である。

## 規約（要約）

1. **属性の正規化**（`normalize_attrs_for_create` / `normalize_attrs_for_update` 相当）は **Interactor** が `Domain::Shared::Policies::*`（または該当コンテキストのポリシー）を呼び、Gateway には **正規化済みの属性 Hash** のみ渡す。Gateway 実装は正規化ロジックを持たない。
2. **一覧の可視スコープ**は `ReferenceIndexListFilter` 等の **値オブジェクト**と `list_index_for_filter` / `index_relation_for_filter` パターンで表現し、Adapter 内でロール分岐用に `*Policy` を直接参照しない。
3. **認可に基づく読み取り**（`find_authorized_*`）では、Adapter は `lib/domain` に置いた **狭い委譲**（例: `ReferenceMasterAuthorization`）やスコープ記述子の写像に留め、ビジネス判断の単一ソースは **ドメインの Policy** に残す。
4. **削除アンドゥ・関連付け・栽培計画・圃場・天気ジョブチェーン**など横断処理では、分岐判断を **Interactor または `lib/domain` の PORO**（例: `ScheduleAuthorization`, `PlanAccess`, `OptimizationJobChainWeatherComputation`）に集約し、Gateway は **決定済みの引数**（ID 集合、日付範囲、整数日数など）に対する永続化・外部 I/O のみとする。
5. **`app/policies`** に残すラッパーは **HTTP / Pundit 互換の薄い委譲**に限定し、ルール本体は **`lib/domain`** の Plain Ruby に置く。

## 実装チェックリスト

- [ ] 対象ユースケースの Interactor テストで、Gateway に渡る属性が正規化後であること（または VO 経由であること）を確認した。
- [ ] 対応する Gateway 実装テストで、SQL / AR 写像に専念していること（ポリシー直呼びがないこと）を確認した。
- [ ] 変更が横断する場合、本ファイルの該当条項を見直し、必要なら個別 `docs/contracts/*-contract.md` の「サーバー側」の節と矛盾がないことを確認した。

## ステータス

実装済み（本リポジトリのマスタ・削除アンドゥ・計画・圃場・公開プラン最適化チェーンの整理に適用）。
