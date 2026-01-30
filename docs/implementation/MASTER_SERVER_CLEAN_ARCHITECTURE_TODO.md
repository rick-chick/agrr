# マスタAPI サーバー側 Clean Architecture 相違とTODO

スキル（usecase-server, controller-server, presenter-server, gateway-server）と現行実装の相違を洗い出し、対応TODOを列挙する。

---

## 1. 相違サマリ

| 観点 | スキルが求める形 | 現状 | 相違 |
|------|------------------|------|------|
| **Controller** | (1) params → Input DTO 変換 (2) Interactor のインスタンス化（Gateway・Presenter 注入）(3) `interactor.call(input_dto)` で委譲 (4) View の `render_response(json:, status:)` を実装（委譲のみ） | `ApiCrudResponder` を include。Policy + ActiveRecord を直接利用。`respond_to_*` や `schedule_deletion_with_undo` で render。Gateway/Presenter なし。 | Controller が Interactor を呼んでおらず、render を直接実行している。DTO 変換・View 契約なし。 |
| **Interactor** | Input Port を実装。`call(input_dto)` 内で Gateway を呼び、成功時 `output_port.on_success(success_dto)`、失敗時 `output_port.on_failure(failure_dto)`。1 アクション 1 クラス。 | マスタAPIでは未使用。crop/fertilize/pest に一部 Interactor ありだが、Output Port 未使用・引数が Hash 的。 | マスタでは Interactor 経由のフローが無い。既存 Interactor はスキル（DTO・Output Port）に非準拠。 |
| **Presenter** | Output Port を実装。`on_success(success_dto)` / `on_failure(failure_dto)` で **view.render_response(json:, status:)** を呼ぶだけ。View は注入。 | `lib/presenters/api/` は未使用（マスタ用 Presenter なし）。 | マスタ用 Presenter が存在しない。 |
| **View** | `lib/views/api/<domain>/` に契約（例: `render_response(json:, status:)`）を定義。Controller が include し、`render(json: json, status: status)` に委譲して実装。 | `lib/views/api/` は未使用（マスタ用 View 契約なし）。 | マスタ用 View 契約が存在しない。 |
| **Gateway** | usecase 層の Gateway Interface を実装。引数・戻り値は DTO または Entity。Hash 禁止。`lib/adapters/<domain>/gateways/` に配置。 | crop/fertilize/pest に adapter Gateway あり。farm, pesticide, agricultural_task, interaction_rule, field はなし。既存 Gateway の create(attributes) は Hash 的。 | マスタのうち複数で Gateway 未整備。既存も DTO/Entity 厳格化が必要。 |
| **Domain** | `lib/domain/<domain>/` に entities, **ports**（Input/Output Port）, gateways, interactors, dtos。Input/Output Port は Interface として定義。 | crop/fertilize/pest に entities, gateways, 一部 interactors あり。**ports が無い**。farm 等は domain 自体なし。 | 全マスタで ports が未整備。一部は domain 全体が未整備。 |
| **削除（destroy）** | Interactor が削除ロジック（または Gateway 経由で DeletionUndo::Manager.schedule）を実行し、成功時は `on_success(undo_dto)`、失敗時は `on_failure(error_dto)`。Presenter が JSON を render。 | Controller が `schedule_deletion_with_undo`（DeletionUndoFlow）を直接呼び、その中で `render_deletion_undo_response` / `render_deletion_failure`。 | 削除の「駆動」が Controller 直叩き。Interactor/Presenter/View を経由していない。 |

---

## 2. リソース別の現状と不足

| リソース | domain (lib/domain) | ports | Gateway Interface | Adapter Gateway | Interactors (CRUD 5 本) | View (lib/views) | Presenter (lib/presenters) | Controller 接続 |
|----------|---------------------|-------|-------------------|-----------------|--------------------------|------------------|----------------------------|----------------|
| **farm** | あり | あり | あり | FarmActiveRecordGateway | あり（List/Show/Create/Update/Destroy） | あり | あり | Interactor 委譲・Presenter/View |
| **crop** | あり（entities, gateways, 一部 interactors） | なし | あり（create 等。引数 Hash 的） | あり（crop_memory_gateway） | create のみ。Output Port 未使用 | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **fertilize** | あり（entities, gateways, create/update interactors） | なし | あり | あり（memory/cli） | create, update のみ。Output Port 未使用 | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **pest** | あり（entities, gateways, create/update interactors） | なし | あり | あり（memory） | create, update のみ。Output Port 未使用 | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **pesticide** | なし | なし | なし | なし | なし | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **agricultural_task** | なし | なし | なし | なし | なし | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **interaction_rule** | なし | なし | なし | なし | なし | なし | なし | ApiCrudResponder + DeletionUndoFlow |
| **field** | なし | なし | なし | なし | なし | なし | なし | ApiCrudResponder + DeletionUndoFlow |

※ ネスト（crops/agricultural_tasks 等）は別途リスト化可能。

---

## 3. TODO 一覧（推奨順）

### 3.1 共通・基盤

| # | タスク | 内容 |
|---|--------|------|
| G1 | **DeletionUndoFlow の Interactor 化方針** | 削除成功時の JSON（undo_token, toast_message, undo_path 等）を「Destroy Interactor の success_dto」とし、Presenter の `on_success` で `view.render_response(json: ..., status: :ok)` を呼ぶ形に整理。DeletionUndoFlow は「Interactor から呼ばれるサービス」または Gateway 経由にし、Controller は Interactor のみ駆動する。 |
| G2 | **BaseController での Gateway / Presenter 注入** | マスタ用に、Gateway と Presenter を取得するメソッド（または DI）を用意。各 Controller はそれを使って Interactor を組み立て、`interactor.call(input_dto)` する。 |
| G3 | **ApiCrudResponder の廃止方針** | スキル準拠後は各アクションで Interactor 経由の render のみにするため、マスタ系から `ApiCrudResponder` を外す。respond_to_* の代わりに Presenter が view.render_response を呼ぶ。 |

### 3.2 Domain 層（lib/domain/<domain>）

| # | リソース | タスク | 内容 |
|---|----------|--------|------|
| D1 | farm | domain 新規 | entities, ports（Input/Output 各アクション）, gateways（Interface）, dtos, interactors（List, Show, Create, Update, Destroy）を追加。 |
| D2 | crop | ports 追加・既存のスキル準拠化 | ports を追加。既存 Gateway の引数・戻り値を DTO/Entity に。既存 Interactor を Output Port 対応・DTO 受けに変更。List/Show/Destroy Interactor を追加。 |
| D3 | fertilize | 同上 | ports 追加。Gateway/Interactor を DTO・Output Port 対応に。List, Show, Destroy Interactor 追加。 |
| D4 | pest | 同上 | 同上。 |
| D5 | pesticide | domain 新規 | farm と同様に entities, ports, gateways, dtos, interactors（List, Show, Create, Update, Destroy）を新規作成。 |
| D6 | agricultural_task | domain 新規 | 同上。 |
| D7 | interaction_rule | domain 新規 | 同上。 |
| D8 | field | domain 新規 | 同上。ネスト（farms/:farm_id/fields）は Input DTO に farm_id を含める。 |

### 3.3 Adapter 層

| # | リソース | タスク | 内容 |
|---|----------|--------|------|
| A1 | farm | Gateway 実装 | `lib/adapters/farm/gateways/farm_memory_gateway.rb` を追加。Policy + Farm モデルを使い、Interface のメソッドを DTO/Entity で実装。削除は DeletionUndo::Manager.schedule を呼び undo 情報を返す形にする。 |
| A2 | crop | Gateway スキル準拠 | 既存 CropMemoryGateway の引数・戻り値を DTO/Entity に統一。削除は Undo 対応。 |
| A3 | fertilize, pest | 同上 | 既存 Memory Gateway を DTO/Entity 厳格化。削除 Undo 対応。 |
| A4 | pesticide, agricultural_task, interaction_rule, field | Gateway 実装 | 各 domain の Gateway Interface を満たす Memory Gateway を新規作成。 |

### 3.4 View・Presenter（lib/views / lib/presenters）

| # | リソース | タスク | 内容 |
|---|----------|--------|------|
| V1 | 全マスタ | View 契約の追加 | `lib/views/api/<domain>/` に各アクション用の View 契約（`render_response(json:, status:)`）を定義。Controller が include して `render(json: json, status: status)` に委譲。 |
| P1 | 全マスタ | Presenter の追加 | `lib/presenters/api/<domain>/` に各アクション用の Presenter を追加。Output Port を実装し、on_success / on_failure で view.render_response を呼ぶ。destroy は on_success で undo JSON を render。 |

### 3.5 Controller の書き換え

| # | リソース | タスク | 内容 |
|---|----------|--------|------|
| C1 | farm | Controller スキル準拠 | ApiCrudResponder を外す。params → Input DTO、Interactor のインスタンス化（gateway, presenter 注入）、interactor.call(input_dto)。View の render_response を実装。index/show/create/update/destroy の 5 アクションをすべて Interactor 委譲に。 |
| C2 | crop, fertilize, pest, pesticide, agricultural_task, interaction_rule, field | 同上 | 同上。各マスタで 5 アクションを Interactor + Presenter + View に統一。 |

### 3.6 削除フロー（destroy）の整理

| # | タスク | 内容 |
|---|--------|------|
| U1 | Destroy Interactor で Undo を返す | 各リソースの Destroy Interactor 内で、Gateway またはサービス経由で `DeletionUndo::Manager.schedule` を実行。成功時は undo_token, toast_message, undo_path 等を含む success_dto を組み立て、output_port.on_success(success_dto) を呼ぶ。失敗時は output_port.on_failure(error_dto)。 |
| U2 | DeletionUndoFlow の利用範囲縮小 | マスタAPIでは Controller が DeletionUndoFlow（schedule_deletion_with_undo）を直接呼ばないようにする。Interactor 経由にした上で、既存の DeletionUndoResponder（render_deletion_undo_response 等）は Presenter 側で同じ JSON を組み立てて view.render_response で返す形に寄せる。 |

---

## 4. 実装順の提案

1. **1 リソースでスキル通りに揃える（例: farm）**  
   G2 の一部（farm 用の gateway/presenter 取得）、D1, A1, V1（farm 分）, P1（farm 分）, C1（farm）, U1（farm の destroy）。これで「1 マスタ完全スキル準拠」を達成。
2. **crop / fertilize / pest の既存 domain をスキル準拠に拡張**  
   D2–D4, A2–A3, V1/P1/C2 の該当分。既存 Interactor の Output Port 化・DTO 化を含める。
3. **残りマスタの domain + adapter + view + presenter + controller**  
   D5–D8, A4, V1/P1/C2 の残り。
4. **G1, G3, U2**  
   削除フローと BaseController の整理、ApiCrudResponder のマスタからの削除。

---

## 5. 参照

- スキル: `.cursor/skills/usecase-server/`, `controller-server/`, `presenter-server/`, `gateway-server/`
- 現行 CRUD: `app/controllers/concerns/api_crud_responder.rb`
- 現行削除 Undo: `app/controllers/concerns/deletion_undo_flow.rb`, `deletion_undo_responder.rb`
- 既存 domain 例: `lib/domain/crop/`, `lib/domain/fertilize/`, `lib/domain/pest/`
- 既存 adapter 例: `lib/adapters/crop/gateways/crop_memory_gateway.rb`
