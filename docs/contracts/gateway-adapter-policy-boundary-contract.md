# Gateway アダプターとポリシー境界（バックエンド横断）

## 目的

`ARCHITECTURE.md` の **Gateway boundary (presentation-agnostic)** に沿い、マスタ系・永続化アダプターと `lib/domain` の責務分担を固定する。Angular ↔ API の個別機能契約（`crop-contract.md` 等）とは別の **レイヤー運用契約**である。

## 規約（要約）

1. **属性の正規化**（`normalize_attrs_for_create` / `normalize_attrs_for_update` 相当）は **Interactor** が `Domain::Shared::Policies::*`（または該当コンテキストのポリシー）を呼び、Gateway には **正規化済みの属性 Hash** のみ渡す。Gateway 実装は正規化ロジックを持たない。
2. **一覧の可視スコープ**は `ReferenceIndexListFilter` 等の **値オブジェクト**と `list_index_for_filter` / `index_relation_for_filter` パターンで表現し、Adapter 内でロール分岐用に `*Policy` を直接参照しない。
3. **認可に基づく読み取り・更新**（`find_authorized_*` / `update_for_user` 等）は、**一覧と同型**とする: Interactor が `XxxPolicy.record_access_filter(user)`（圃場まわりは `FarmPolicy.record_access_filter` を `farm_access_filter:` として）が返す **狭い値オブジェクト**（例: `ReferenceRecordAccessFilter`）を組み立て Gateway に渡し、Adapter は **VO の内容を SQL／永続写像に写すだけ**とする。Adapter が `*Policy` 定数を import してロール分岐しない。栽培計画の private スコープ写像は `CultivationPlanActiveRecordGateway` 内の **プライベートメソッド**に閉じ、`PlanAccess` を Adapter から参照しない。REST 用の栽培計画1件取得は **アダプター層**の `Adapters::CultivationPlan::RestAuthorizedCultivationPlanLoader` に置き、Relation 条件は `PlanAccess.private_scope` / `public_scope` と同義であることをコメントで明示する（`PlanAccess` クラス自体は import しない）。
4. **削除アンドゥ・関連付け・天気ジョブチェーン**など横断処理では、分岐判断を **Interactor または `lib/domain` の PORO**（例: `ScheduleAuthorization`, `OptimizationJobChainWeatherComputation`）に集約し、Gateway は **決定済みの引数**（ID 集合、日付範囲、整数日数、`access_filter` / `farm_access_filter` など）に対する永続化・外部 I/O のみとする。**`ActiveRecord::Relation` を Interactor が Gateway へ渡すことは禁止**（必要なら id ＋ VO まで落とす）。
5. **`app/policies`** に残すラッパーは **HTTP / Pundit 互換の薄い委譲**に限定し、ルール本体は **`lib/domain`** の Plain Ruby に置く。

## 実装チェックリスト

- [ ] 対象ユースケースの Interactor テストで、Gateway に渡る属性が正規化後であること（または VO 経由であること）を確認した。
- [ ] 対応する Gateway 実装テストで、SQL / AR 写像に専念していること（ポリシー直呼びがないこと）を確認した。
- [ ] 変更が横断する場合、本ファイルの該当条項を見直し、必要なら個別 `docs/contracts/*-contract.md` の「サーバー側」の節と矛盾がないことを確認した。

## ステータス

実装済み（本リポジトリのマスタ・削除アンドゥ・計画・圃場・公開プラン最適化チェーンの整理に適用）。
