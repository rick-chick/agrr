# Naming & Placement Migration Plan

ARCHITECTURE.md の [Naming and placement conventions](../../ARCHITECTURE.md#naming-and-placement-conventions) と [Prohibited practices 31–38](../../ARCHITECTURE.md#naming-and-placement-items-3138) に既存コードを揃えるための、context 単位の段階的移行計画。

**位置づけ**：本書は実装手順のみ。規約本体は ARCHITECTURE.md が正であり、矛盾があれば ARCHITECTURE.md を優先する。

## 目的

現状の主なゆらぎ（棚卸し結果より）：

- **配置のゆらぎ**：`lib/adapters/` と `app/gateways/`、`lib/presenters/` と `app/presenters/`
- **Gateway adapter サフィックスの 9 種類**：`_active_record_gateway`、`_gateway_adapter`、`_active_gateway`、`_through_host_gateway`、`_active_job_gateway`、`_action_cable_gateway`、`_cli_gateway`、`_memory_gateway`、`rails_*_gateway`、サフィックスなし `*_gateway.rb`
- **Gateway メソッドの検索動詞のゆらぎ**：`find_*` / `fetch_*` / `load_*` / `get_*` / `list_*` / `query_*` / `by_*`
- **Interactor 実行メソッドのゆらぎ**：`call` (167) / `execute` (3 / weather_data) / `perform` (0)
- **DTO の役割サフィックスのゆらぎ**：`_dto` (201)、`_snapshot` (18)、`_read_model` (4)、`_result_dto`、`_payload_dto`、`persisted_*` 接頭辞
- **Presenter の配置のゆらぎ**：`lib/presenters/api/<resource>/`、`lib/presenters/html/<resource>/`、`lib/presenters/<feature>/`（cross-context 直置き）

## 移行原則

1. **1 context 完了 → 次へ**。中途半端な状態（半分は新配置、半分は旧配置）を残さない。
2. **同一 PR で context 内の全 Phase を完了する**。Phase A〜F は 1 PR に束ねる。途中で merge しない。
3. **PR 完了時に test-common 経由で全 Rails テストを実行**し GREEN を確認。`.cursor/skills/test-common/scripts/run-test-rails.sh` を使う。
4. **コミットメッセージ**に該当する Prohibited 項番（31〜38）を明示する。
5. **本書の context 節は完了時に [x] にチェック**し、PR / commit 番号を併記する。

## 各 context の Phase 構成

| Phase | 内容 | 対象 |
|---|---|---|
| **0** | （全 context 共通の事前作業：autoload 設定とスキャンスクリプト） | 1 回のみ |
| **A** | 配置移動：`lib/adapters/<ctx>/` → `app/adapters/<ctx>/`、`lib/presenters/{api,html}/<resource>/` → `app/adapters/<ctx>/presenters/` | 全 context |
| **B** | Gateway 実装ファイル名のサフィックス統一（`_gateway_adapter` / `_active_gateway` / `_through_host_gateway` / `rails_*` を解消） | 該当 context のみ |
| **C** | Gateway interface のメソッド名統一（4 動詞 + `find_authorized_*_for_*`、`fetch_*` / `get_<entity>` / `load_*` / `query_*` / `by_*` を解消） | 全 context |
| **D** | Interactor 実行メソッドの `call` 統一（`execute` / `perform` を解消） | weather_data のみ（既存 3 件） |
| **E** | DTO 命名統一（`_dto` 接尾辞除去、`persisted_*` 接頭辞除去、`_read_model` / `_payload_dto` は Presenter 側 `view_models/` へ移動） | 全 context（DTO 数による） |
| **F** | Presenter 側 helper（Form / ViewModel / Mapper）への分割。新規 helper を導入する場合のみ。既存 Presenter が肥大化しているもののみ対象。 | 任意 |

## Phase 0：全 context 共通の事前作業

これらを **最初の PR** で済ませる。以降の context 移行 PR は Phase 0 に依存する。

### 0-1. Zeitwerk autoload 設定

- `config/application.rb` を確認：`app/adapters/` は Zeitwerk のデフォルトで autoload 対象（`app/` 直下のサブディレクトリは自動）。明示追加は不要だが、名前空間 `Adapters::<Context>::Gateways::*` / `Adapters::<Context>::Presenters::*` で解決できることを inflections と合わせて確認。
- 命名規約（クラス名）：
  - `app/adapters/farm/gateways/farm_active_record_gateway.rb` → `Adapters::Farm::Gateways::FarmActiveRecordGateway`
  - `app/adapters/farm/presenters/farm_create_api_presenter.rb` → `Adapters::Farm::Presenters::FarmCreateApiPresenter`
  - `app/adapters/farm/presenters/forms/farm_create_form.rb` → `Adapters::Farm::Presenters::Forms::FarmCreateForm`

### 0-2. ゆらぎ検出スクリプト

`bin/lint-naming-placement`（新規）を追加し、CI で実行する。検出パターン：

| パターン | 検出 |
|---|---|
| `lib/adapters/**/*.rb` の存在 | 旧配置（Phase A 未完了） |
| `lib/presenters/**/*.rb` の存在 | 旧配置（Phase A 未完了） |
| `app/gateways/**/*.rb`（`agrr/` 除く） | 旧配置 |
| `app/adapters/**/*_gateway_adapter.rb` | サフィックス違反（31） |
| `app/adapters/**/*_active_gateway.rb` | サフィックス違反（31） |
| `app/adapters/**/*_through_host_gateway.rb` | サフィックス違反（32） |
| `**/*_rest_*_gateway.rb` / `**/*_html_*_gateway.rb` / `**/*_json_*_gateway.rb` | presentation channel infix（禁止 39） |
| `lib/domain/logger/gateways/` の存在 | logger は port（決定 §-2） |
| `app/adapters/**/gateways/*_gateway.rb`（adapter qualifier なし） | サフィックス違反（31） |
| `lib/domain/**/*_dto.rb` | DTO 命名違反（35） |
| `lib/domain/**/persisted_*.rb` | DTO 命名違反（36） |
| `lib/domain/**/*_read_model.rb` | Domain への presenter shape 流入（36） |
| `lib/domain/**/*_payload_dto.rb` | 同上（36） |
| Interactor 内の `def execute` / `def perform` | 実行メソッド違反（34） |
| Gateway interface 内の `def fetch_*`（DB I/O 用途） / `def get_<entity>` / `def load_*` / `def query_*` | メソッド命名違反（33） |

スクリプト終了コードでゲートし、CI に組み込む。

### 0-3. ARCHITECTURE.md の参照リンク追加

完了。本書を ARCHITECTURE.md から参照済み。

### 0-4. CLAUDE.md / docs の参照更新

CLAUDE.md と `docs/ca-violations-backlog.md` で「禁止 1–30」と書いている箇所を「禁止 1–39」または「禁止 1–30、31–39」に更新。本 PR でまとめて実施。

### 0-5. logger port 化 ADR の起票（決定 §-2 の前提）

`docs/adr/<NNNN>-logger-as-port.md` を新規作成し、logger を gateway から port に再分類する判断と影響範囲を記録。logger context の Phase A はこの ADR 採用後に実施する。

## Context 移行リスト（22 context）

各 context の右列「規模感」は **Phase E（DTO リネーム）の対象件数の目安**。Phase A は全 context 共通、Phase C は interface 1〜数件、Phase B/D は該当時のみ。

| # | Context | A | B | C | D | E | F | 規模感 | 備考 |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `agricultural_task` | ☐ | ☐ | ☐ |   | ☐ | ☐ | 中 | `task_schedule_gateway` 含む 2 interface |
| 2 | `api_keys` | ☐ |   | ☐ |   | ☐ |   | 小 | `user_api_key_rotation_gateway` |
| 3 | `api_weather` | ☐ | ☐ | ☐ |   | ☐ |   | 小 | `agrr_service_weather_query_active_gateway.rb` の実体確認。agrr daemon 経由なら `_daemon_gateway`（`app/adapters/agrr/gateways/` へ）。それ以外なら `_active_record_gateway` |
| 4 | `auth` | ☐ |   | ☐ |   | ☐ |   | 小 | 2 gateway |
| 5 | `backdoor` | ☐ |   | ☐ |   | ☐ |   | 小 | `application_database_clear_gateway` |
| 6 | `contact_messages` | ☐ |   | ☐ |   | ☐ |   | 小 | |
| 7 | `crop` | ☐ |   | ☐ |   | ☐ | ☐ | 大 | 4 gateway interface、DTO 多数（snapshot 含む） |
| 8 | `cultivation_plan` | ☐ | ☐ | ☐ |   | ☐ | ☐ | **特大** | 11 gateway interface、`_gateway_adapter` / `_action_cable_gateway` / `_through_host_gateway` / `_result_payload_dto` 集中。**Phase B 必須**。詳細節参照。 |
| 9 | `deletion_undo` | ☐ |   | ☐ |   | ☐ | ☐ | 中 | `lib/presenters/deletion_undo/` 直下に cross-context presenter あり、配置検討 |
| 10 | `farm` | ☐ |   | ☐ |   | ☐ |   | 中 | 標準的な CRUD |
| 11 | `fertilize` | ☐ | ☐ | ☐ |   | ☐ |   | 中 | `fertilize_cli_gateway.rb` あり（サフィックス OK） |
| 12 | `field` | ☐ |   | ☐ |   | ☐ |   | 中 | `policies/` `results/` 持ち |
| 13 | `field_cultivation` | ☐ |   | ☐ |   | ☐ |   | 中 | `field_cultivation_climate_gateway`（実体は HTTP）→ `_http_gateway` へ |
| 14 | `file_blob` | ☐ |   | ☐ |   | ☐ |   | 小 | **注意**：実装が `lib/adapters/stored_blobs/` にある（context 名不一致）。Phase A で `app/adapters/file_blob/` に統一 |
| 15 | `interaction_rule` | ☐ |   | ☐ |   | ☐ |   | 小 | |
| 16 | `internal_jobs` | ☐ | ☐ |   |   | ☐ |   | 小 | `_active_job_gateway` あり（OK）。配置のみ移動 |
| 17 | `logger` | ☐ | ☐ |   |   |   |   | 極小 | **port 化（決定 §-2）**：`lib/domain/logger/gateways/` → `ports/`、実装は `app/adapters/logger/rails_logger_adapter.rb`。Phase 0 で ADR 起票を先行 |
| 18 | `pest` | ☐ |   | ☐ |   | ☐ | ☐ | 大 | `policies/` `value_objects/` `services/` 持ち |
| 19 | `pesticide` | ☐ |   | ☐ |   | ☐ |   | 中 | |
| 20 | `public_plan` | ☐ |   | ☐ |   | ☐ | ☐ | 大 | `public_plan_results_read_model` / `*_optimizing_read_model` → Presenter ViewModel へ（**Phase F 必須**） |
| 21 | `shared` | ☐ |   | ☐ |   | ☐ |   | 中 | `lib/adapters/shared/` に context 横断 gateway。配置整理を別途検討（本書 §「shared の扱い」） |
| 22 | `weather_data` | ☐ | ☐ | ☐ | ☐ | ☐ | ☐ | **特大** | `execute` メソッド 3 件、`gcs_weather_data_gateway` → `weather_data_gcs_http_gateway`（決定 §-1）、`agrr_prediction_gateway_adapter` → `app/adapters/agrr/gateways/prediction_daemon_gateway`、`_payload_dto` あり、独自 `contracts/` `input_ports/` `presenters/` 持ち |

加えて、ドメインに属さない adapter ディレクトリ：

| Path | 移行先 |
|---|---|
| `app/gateways/agrr/` | `app/adapters/agrr/gateways/`。`base_gateway.rb` / `base_gateway_v2.rb` の二重化は v2 統一の判断（別 PR で v1 削除） |
| `lib/adapters/stored_blobs/` | `app/adapters/file_blob/`（context 名統一） |
| `lib/adapters/api/`、`lib/adapters/plans/`、`lib/adapters/public_plans/`、`lib/adapters/translators/`、`lib/adapters/application/` | **要調査**：context への所属を特定して該当 context へ。`translators/` は `shared/` に統合候補 |

## 標準作業手順（1 context あたり）

`<ctx>` を実 context 名に置き換えて作業する。

### Step 1：Phase A（配置移動）

```sh
# gateways
git mv lib/adapters/<ctx> app/adapters/<ctx>

# presenters（api / html それぞれ）
mkdir -p app/adapters/<ctx>/presenters
git mv lib/presenters/api/<ctx> app/adapters/<ctx>/presenters/api 2>/dev/null || true
git mv lib/presenters/html/<ctx> app/adapters/<ctx>/presenters/html 2>/dev/null || true
# または api/ html/ 入れ子をやめてファイル名で区別する場合：
# 各 *_presenter.rb を <usecase>_api_presenter.rb / <usecase>_html_presenter.rb にリネームしてフラットに置く
```

namespace 一括置換：

```sh
# Adapters::<Ctx>:: は変わらないので gateways 側は通常不要
# Presenters:: が新たな namespace の場合、controllers / tests の参照を grep して更新
git grep -l "Presenters::Api::<Ctx>" -- "app/" "test/" "lib/" \
  | xargs sed -i 's/Presenters::Api::<Ctx>/Adapters::<Ctx>::Presenters/g'
```

参照側ファイル：

- `app/controllers/**/<ctx>_controller.rb` / `app/controllers/api/v1/**/*<ctx>*.rb`
- `lib/composition_root.rb`
- `test/adapters/<ctx>/` / `test/presenters/<ctx>/` / `test/controllers/...`

### Step 2：Phase B（Gateway 実装ファイル名）

`bin/lint-naming-placement` の出力に従い、該当 context の違反ファイルをリネーム：

```sh
# 例：cultivation_plan
git mv app/adapters/cultivation_plan/gateways/plan_allocation_gateway_adapter.rb \
       app/adapters/cultivation_plan/gateways/plan_allocation_active_record_gateway.rb
# クラス名もファイル名と一致させる
sed -i 's/PlanAllocationGatewayAdapter/PlanAllocationActiveRecordGateway/g' \
  app/adapters/cultivation_plan/gateways/plan_allocation_active_record_gateway.rb \
  $(git grep -l PlanAllocationGatewayAdapter)
```

### Step 3：Phase C（Gateway メソッド）

ARCHITECTURE.md の 4 動詞表に照らし、interface と全実装で同期リネーム：

| 旧 | 新 |
|---|---|
| `fetch_<entity>` (DB I/O) | `find_by_<key>` or `list_by_<criteria>` |
| `get_<entity>(id)` | `find_by_id(id)` |
| `load_<entity>(id)` | `find_by_id(id)` |
| `query_<...>` | `list_by_<criteria>` |
| `by_<criteria>` | `list_by_<criteria>` |
| `find_<entity>` 単独 | `find_by_id` / `list_by_*` のどちらか役割を明確化 |
| 既存 `fetch_*`（外部 HTTP I/O） | 維持（規約で許容） |
| 既存 `get_<state>`（progress, count 等） | 維持（規約で許容） |
| 既存 `find_authorized_<entity>_for_<action>` | 維持（標準形） |
| 既存 `soft_destroy_with_undo` | 維持（標準形） |

interface と全実装、interactor 内呼び出し、テストを同 PR で更新。

### Step 4：Phase D（Interactor 実行メソッド）

`def execute(` を grep して `def call(` に置換、呼び出し側も同期。weather_data の 3 ファイル：

- `lib/domain/weather_data/interactors/fetch_weather_data_perform_interactor.rb`
- `lib/domain/weather_data/interactors/fetch_weather_data_retry_on_interactor.rb`
- `lib/domain/weather_data/interactors/fetch_weather_data_discard_on_interactor.rb`

Job 側（`app/jobs/fetch_weather_data_job.rb` 等）の呼び出しも `interactor.call(...)` に統一。

### Step 5：Phase E（DTO 命名）

ファイル名・クラス名を一括リネーム：

| 旧 | 新 |
|---|---|
| `<usecase>_input_dto.rb` / `<Usecase>InputDto` | `<usecase>_input.rb` / `<Usecase>Input` |
| `<usecase>_output_dto.rb` / `<Usecase>OutputDto` | `<usecase>_output.rb` / `<Usecase>Output` |
| `<usecase>_failure_dto.rb` / `<Usecase>FailureDto` | `<usecase>_failure.rb` / `<Usecase>Failure` |
| `<usecase>_success_dto.rb` / `<Usecase>SuccessDto` | `<usecase>_output.rb` / `<Usecase>Output`（success は明示せず Output に統一） |
| `<usecase>_result_dto.rb` / `<Usecase>ResultDto` | `<usecase>_output.rb` / `<Usecase>Output`（戻り値の意味なら Output に統一） |
| `persisted_<name>.rb` / `Persisted<Name>` | `<name>_snapshot.rb` / `<Name>Snapshot` |
| `<name>_snapshot_dto.rb` / `<Name>SnapshotDto` | `<name>_snapshot.rb` / `<Name>Snapshot` |
| `<name>_read_model.rb` / `<Name>ReadModel` | **移動**：`app/adapters/<ctx>/presenters/view_models/<usecase>_view_model.rb`（要 Phase F） |
| `<name>_payload_dto.rb` / `<Name>PayloadDto` | **移動**：上に同じ、または presenter 側 `mappers/` |

リネームスクリプト例（context 単位）：

```sh
# Input
for f in $(find lib/domain/<ctx>/dtos -name '*_input_dto.rb'); do
  new="${f%_input_dto.rb}_input.rb"
  git mv "$f" "$new"
done
# クラス名
git grep -l "InputDto" lib/domain/<ctx> test/domain/<ctx> | xargs sed -i 's/InputDto/Input/g'
```

参照側（interactor、presenter、controller、test）も同 PR で全て更新。

### Step 6：Phase F（Presenter helper への分割）

該当 Presenter が肥大化していて、Form / ViewModel / Mapper への分割が見合う場合のみ実施：

1. **Form**：HTML の `create` / `update` で `params` 解釈が複雑なものから抽出
2. **ViewModel**：`index` / `show` でビジネスロジック相当のフォーマットが Presenter に混入しているものから抽出
3. **Mapper**：JSON shape が DTO と大きく異なる API presenter から抽出

新規ヘルパーは `app/adapters/<ctx>/presenters/{forms,view_models,mappers}/<usecase>_<role>.rb` に配置。

### Step 7：検証

```sh
.cursor/skills/test-common/scripts/run-test-rails.sh
.cursor/skills/test-common/scripts/run-test-domain-lib.sh
bin/lint-naming-placement   # 該当 context が違反 0 件であることを確認
```

GREEN を確認してから本書の対象行に `[x]` を入れ、PR / commit SHA を記載してコミット。

## 特殊 context の詳細

### cultivation_plan（特大）

最も複雑な context。Phase B が必須。**決定事項 §-1 / §-4 の適用先**。

**Phase B 対象ファイル**：

- `lib/adapters/cultivation_plan/gateways/plan_allocation_gateway_adapter.rb` → `app/adapters/cultivation_plan/gateways/plan_allocation_active_record_gateway.rb`（`_gateway_adapter` 違反）
- `lib/adapters/cultivation_plan/gateways/cultivation_plan_rest_add_crop_coordinator_active_record_gateway.rb` → `cultivation_plan_add_crop_coordinator_active_record_gateway.rb`（`rest_` 中置除去、決定 §-4）
- `lib/adapters/cultivation_plan/gateways/cultivation_plan_rest_field_mutation_active_record_gateway.rb` → `cultivation_plan_field_mutation_active_record_gateway.rb`（同上）
- `lib/adapters/cultivation_plan/gateways/cultivation_plan_rest_workbench_payload_active_record_gateway.rb` → `cultivation_plan_workbench_payload_active_record_gateway.rb`（同上）
- `lib/adapters/cultivation_plan/gateways/cultivation_plan_rest_optimization_events_action_cable_gateway.rb` → `cultivation_plan_optimization_events_action_cable_gateway.rb`（`rest_` 中置除去、`_action_cable_gateway` サフィックスは維持）
- `lib/adapters/cultivation_plan/gateways/cultivation_plan_rest_adjust_through_host_gateway.rb` → **実体確認後** に `cultivation_plan_adjust_daemon_gateway.rb`（agrr daemon 経由想定 → 配置は `app/adapters/agrr/gateways/` 候補）か `_http_gateway.rb`（決定 §-4 適用）。Phase B 実施時に 1 ファイル中身確認

**interface 側の同期 rename**（`lib/domain/cultivation_plan/gateways/`）：

- 上記すべての対応する interface も `rest_` 除去（`cultivation_plan_rest_add_crop_coordinator_gateway.rb` → `cultivation_plan_add_crop_coordinator_gateway.rb` 等）。これは禁止 4（domain での channel 命名）の解消にもなる。

**Phase E 対象**：`_result_payload_dto`、`_success_dto`、`_failure_dto` の整理。Output / Failure に統一。`_result_payload_dto` は presenter 側 view_model 候補（中身次第）。

**Phase F 対象**：private/public plan 系の `_read_model` / `_payload_dto` を Presenter 側 `view_models/` へ移動。

### weather_data（特大）

**決定事項 §-1 / §-2 の適用先**。

**Phase A 前の作業**：`lib/domain/weather_data/presenters/` 直下に置かれている domain 内 presenter コードを再分類：

- 表示形に寄っているものは `app/adapters/weather_data/presenters/` へ
- output port の interface であれば `lib/domain/weather_data/ports/` へ

**Phase B 対象**：

- `lib/adapters/weather_data/gateways/active_record_weather_data_gateway.rb` → `app/adapters/weather_data/gateways/weather_data_active_record_gateway.rb`（`active_record_` 接頭辞除去、context 接頭辞へ）
- `lib/adapters/weather_data/gateways/gcs_weather_data_gateway.rb` → `app/adapters/weather_data/gateways/weather_data_gcs_http_gateway.rb`（決定 §-1：GCS は `_http_gateway` カテゴリ。`gcs` は中央に残してバックエンド識別を保つ）
- `lib/adapters/weather_data/gateways/agrr_prediction_gateway_adapter.rb` → `app/adapters/agrr/gateways/prediction_daemon_gateway.rb`（agrr context へ移動、`_gateway_adapter` 違反解消、`agrr_` 接頭辞は移動先で冗長になるので除去）
- `lib/adapters/weather_data/gateways/internal_weather_fetch_start_active_record_gateway.rb` → `app/adapters/weather_data/gateways/internal_weather_fetch_start_active_record_gateway.rb`（配置移動のみ）

**Phase D 対象**（`execute` → `call`）：

- `lib/domain/weather_data/interactors/fetch_weather_data_perform_interactor.rb`
- `lib/domain/weather_data/interactors/fetch_weather_data_retry_on_interactor.rb`
- `lib/domain/weather_data/interactors/fetch_weather_data_discard_on_interactor.rb`

Job 側（`app/jobs/fetch_weather_data_job.rb` 等）の呼び出しも `interactor.call(...)` に統一。

**Phase E 対象**：`predicted_weather_payload_dto` → Presenter 側 ViewModel。`weather_location_facts_dto` / `weather_prediction_anchors_dto` → `_dto` 接尾辞除去。

### file_blob / stored_blobs（context 名不一致）

`lib/adapters/stored_blobs/` のファイルは `lib/domain/file_blob/` の interface を実装している。Phase A で `app/adapters/file_blob/gateways/` に統一する。同時に旧 `stored_blobs` ディレクトリは削除。

### shared の扱い

`lib/adapters/shared/` には context 横断 gateway（`auth_omniauth`、`user_active_record` など）が混在している。これらは本来：

- ある domain context に明示的に所属するもの（例：`user_active_record` → `auth` か `user`）
- 真に複数 context が共有するもの（例：`omniauth`）

に分類する必要がある。**Phase A の前に分類判断**を行う（別 PR で先行）。

**完了済み：`user_lookup_port` の Gateway 再分類**

`lib/domain/shared/ports/user_lookup_port.rb` は entity / DTO（`UserDto`）を返すため、ARCHITECTURE.md の「Port or Gateway?」判別基準により **Gateway** に再分類した。

| 旧 | 新 |
|---|---|
| `lib/domain/shared/ports/user_lookup_port.rb`（`Domain::Shared::Ports::UserLookupPort`） | `lib/domain/shared/gateways/user_lookup_gateway.rb`（`Domain::Shared::Gateways::UserLookupGateway`） |
| `lib/adapters/shared/gateways/user_active_record_gateway.rb`（`include Domain::Shared::Ports::UserLookupPort`） | 同上（`include Domain::Shared::Gateways::UserLookupGateway`） |

再分類により `lib/domain/shared/ports/` は純粋な Infrastructure ports（logger, translator, sql_like_sanitize）のみとなった。

### logger（決定 §-2：port 化）

**logger は gateway ではなく port** として再分類する。

**Phase 0 で先行する作業**（ADR 起票）：

- `docs/adr/<NNNN>-logger-as-port.md` を新規作成。要旨：logger は entity / DTO を入出力しない、典型的な「片方向の framework driver 出力」であり、ARCHITECTURE.md の「Port or Gateway?」判別基準により port に分類する。

**Phase A 実施内容**：

| 旧 | 新 |
|---|---|
| `lib/domain/logger/gateways/logger_gateway.rb` | `lib/domain/logger/ports/logger_port.rb`（クラス名 `Domain::Logger::Gateways::LoggerGateway` → `Domain::Logger::Ports::LoggerPort`） |
| `lib/adapters/logger/gateways/rails_logger_gateway.rb` | `app/adapters/logger/rails_logger_adapter.rb`（クラス名 `Adapters::Logger::Gateways::RailsLoggerGateway` → `Adapters::Logger::RailsLoggerAdapter`） |
| 参照側（`logger:` 引数を持つ全 interactor、`CompositionRoot.logger_gateway`） | 引数名・メソッド名・const をすべて `*_port` / `*Port` 系に統一 |

`bin/lint-naming-placement` で `lib/domain/logger/gateways/` の存在を違反として検出。

## 決定事項（旧「未決事項」を確定）

| § | 論点 | 決定 | 影響 |
|---|---|---|---|
| **§-1** | ストレージ系 adapter type | **GCS / S3 などは `_http_gateway` カテゴリ**。バックエンド種別はファイル名の中央に残して識別する（例：`weather_data_gcs_http_gateway.rb`）。新 adapter type の追加は ADR が必要。 | 規約：allowed adapter-type suffixes を 7 種で固定（ARCHITECTURE.md 反映済み）。weather_data の Phase B で `gcs_weather_data_gateway.rb` を `weather_data_gcs_http_gateway.rb` にリネーム |
| **§-2** | logger | **port 化（推奨 C）**。`lib/domain/logger/gateways/` を `ports/` に移動、実装を `app/adapters/logger/rails_logger_adapter.rb` に。Phase 0 で ADR 起票を先行 | ARCHITECTURE.md に「Port or Gateway?」判別基準と Port file naming テーブルを追加（反映済み）。logger context の Phase A は ADR 採用後に実施 |
| **§-3** | agrr v1/v2 二重化 | **Phase A で v1/v2 両方をそのまま `app/adapters/agrr/gateways/` に移動**。v2 統一は別 doc（`docs/planning/agrr_gateway_v2_migration.md`）で継続 | agrr Phase A の review が肥大化しない。v2 統一の進捗と独立 |
| **§-4** | `cultivation_plan_rest_*` の `rest_` 中置と `_through_host_gateway` | **`rest_` は全面除去。`_through_host_gateway` は実体に応じ `_daemon_gateway`（agrr 経由想定）または `_http_gateway` に置換**。Gateway 名に presentation channel を含めないことを禁止 39 として明文化 | ARCHITECTURE.md 禁止 39 追加（反映済み）。cultivation_plan の Phase B で interface / 実装 / 参照を同 PR でリネーム |

## 完了条件

1. 全 22 context が本書の表で全 Phase チェック済み
2. `bin/lint-naming-placement` 違反 0 件
3. `lib/adapters/` 配下 0 ファイル
4. `lib/presenters/` 配下 0 ファイル
5. `app/gateways/` 配下に `agrr/` を含めて 0 ファイル（agrr は `app/adapters/agrr/` へ）
6. test-common 経由の Rails / domain-lib / frontend テストが GREEN
7. ARCHITECTURE.md / CLAUDE.md / `docs/ca-violations-backlog.md` の参照リンク・項番が一貫している

## リスクと注意点

- **Zeitwerk のクラス名解決**：autoload の inflections / namespace に齟齬があるとアプリ起動時にエラー。Phase A 直後の boot を必ず確認。
- **テストファイルの配置**：`test/adapters/<ctx>/` `test/presenters/<ctx>/` も同期して動かす。`test/domain/` は変えない（domain は移動しない）。
- **CompositionRoot の参照**：`lib/composition_root.rb` の `Adapters::<Ctx>::Gateways::...new` 参照が namespace 変更で壊れやすい。grep で漏れなく追跡。
- **i18n キー**：DTO のクラス名が view から `t(".#{model.class.name.underscore}")` 等で間接参照されている場合、ロケールキーも更新が必要（grep で確認）。
- **不可逆的な統合**：`stored_blobs` → `file_blob` のような context 統合は元に戻しにくい。判断は本書 §「未決事項」を整理してから。
