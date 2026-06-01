# AGRR Architecture Documentation

## System Overview

AGRR is an agricultural planning and optimization system: an **Angular 21 SPA** uses **agrr-server** (Rust / Axum on Cloud Run) for JSON API, WebSocket (`/cable`), and OAuth (`/auth/*`). Adapters stay thin; domain logic is pure and lives in **`agrr-domain`**.

A **Rails shell** remains for local SPA fallback, static pages, and dev/test helpers only—not production business API. Migration status: [`docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md`](docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md).

**Technology stack**


| Layer               | Technology                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------------- |
| Frontend            | Angular 21 SPA (Clean Architecture-oriented layers under `frontend/src/app/`)                  |
| Frontend hosting    | Google Cloud Storage + Cloud CDN (see `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh`) |
| Backend (API/WS)    | **agrr-server** (Rust) on **Google Cloud Run** — `.cursor/skills/deploy-server/scripts/gcp-deploy.sh` |
| Rails shell (dev)   | SPA fallback・`auth_test`・静的ページのみ（本番 API/WS/auth は Rust）                                 |
| Database            | SQLite3 (**primary** / **cache**); **Litestream** replica to GCS. Schema: **refinery** via `agrr-migrate` on deploy. Jobs: Rust Tokio chains + internal HTTP ([`PROVISIONAL-STACK.md`](docs/migration/app-rust-stack/PROVISIONAL-STACK.md)). Solid Queue not used. |
| Primary integration | **agrr** Python binary / daemon for optimization and weather-related workloads                 |
| Contract-first API  | `test/contract/**` + [`scripts/run-rust-contract-tests.sh`](scripts/run-rust-contract-tests.sh); domain in `crates/agrr-domain` |


**Architecture (production):** Decoupled **Angular SPA + agrr-server**. Deletion undo is **Angular-only** (no Rust server templates). **Rails shell** serves HTML fallback routes, legal pages, API docs, and dev/test mocks when run locally—not master CRUD, planning API, OAuth, or ActionCable in production.




## System Flow

```mermaid
flowchart TD
  User[User] --> CDN[CloudCDN]
  CDN --> GCS[GCS_static_SPA]
  User --> LB[LoadBalancer_agrr.net]
  LB --> CloudRun[agrr-server_CloudRun]
  CloudRun --> SQLite[(SQLite_primary)]
  CloudRun --> Litestream[Litestream_GCS]
  CloudRun --> AgrrDaemon[Agrr_daemon_binary]
```



## Backend

> **Runtime (P7):** Production HTTP/WS/auth run in `crates/agrr-server` with `agrr-domain` and `agrr-adapters-*`. Ruby `lib/domain` and `app/controllers/api` are removed. Diagrams and paths below state **layer rules** the Rust stack follows; map `lib/domain` → `crates/agrr-domain`, `app/adapters` → `crates/agrr-adapters-*`, Rails controller edge → Axum handlers and `crates/agrr-server/src/composition.rs`.

Business logic lives in **`crates/agrr-domain/`** (formerly `lib/domain/`). `lib/core/` holds external binaries and native code.

### API Layer

One JSON action = **one top-level** `Interactor#call`, with **one output port** for that action (usually a Presenter). **Sub-steps** inside the same user-facing use case invoke sibling interactors via **Input port** injection; each sub-step is built at the edge with **its own** `output_port` for that invocation (Presenter, collector, etc.).

#### Roles and Dependencies

1. **Controller** — HTTP entry point. Uses a **request mapper** (Form or adapter mapper) to build input DTOs from `params`, instantiates Presenter and Interactor, injects gateways from `CompositionRoot`, then `interactor.call(input_dto)`.
2. **Presenter** (`app/adapters/<context>/presenters/...`) — Output port implementation. Receives `on_success(dto)` / `on_failure(dto)` and maps to HTTP responses.
3. **Output port** (`lib/domain/.../ports/...`) — Callback contract (`on_success` / `on_failure`) that Interactors call; Presenters implement it.
4. **Input port** (`lib/domain/.../ports/...`, optional) — Narrow contract for invoking a **sibling sub-step** (`call(input_dto)`). The orchestrator depends on the port type, not the concrete `Interactor`. The sub-step `Interactor` **implements** the Input port and is **built at the edge** with its own `output_port`. See [Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection).
5. **Interactor** (`lib/domain/.../interactors/...`) — Use case. Calls injected gateways and optional **Input ports** (nested sub-steps); decides success/failure; calls `output_port.on_success` / `on_failure`.
6. **Gateway interface** (`lib/domain/.../gateways/...`) — Domain-side contract for retrieval, persistence, etc.
7. **Gateway implementation** (`app/adapters/<context>/gateways/...`) — Implements Gateway interfaces using SQLite / ActiveRecord / HTTP. Injected by `CompositionRoot`.

```mermaid
flowchart TB
  subgraph http["HTTP"]
    REQ[JSON request]
    RES[JSON response]
  end
  subgraph app_edge["Rails edge app/controllers/api/v1"]
    CTRL[Controller]
    REQMAP[Request mapper Form or adapter mapper]
  end
  subgraph domain_core["lib/domain same bounded context"]
    IP[Input port optional]
    IU[Interactor]
    GIF[Gateway interface]
    OPORT[Output port contract]
  end
  subgraph presentation["app/adapters/context/presenters"]
    PRES[Presenter]
  end
  subgraph adapters["app/adapters/context/gateways"]
    GADP[Gateway adapter]
  end
  subgraph io["Outside world"]
    DB[(DB files HTTP etc)]
  end

  REQ --> CTRL
  CTRL --> REQMAP
  REQMAP -->|"Input DTO"| CTRL
  CTRL -->|"call(input_dto)"| IU
  CTRL -->|"instantiates"| PRES
  CTRL -->|"instantiates"| GADP
  CTRL -->|"injects output_port"| IU
  CTRL -->|"injects gateway"| IU
  IU -.->|optional| IP
  PRES -.->|implements| OPORT
  GADP -.->|implements| GIF
  IU -->|"calls gateway methods"| GADP
  GADP --> DB
  IU -->|"on_success on_failure"| PRES
  PRES -->|"render_response"| CTRL
  CTRL --> RES
```



#### Checklist

1. Strong-params → **request mapper or Form** → **input DTO** (see [Canonical use-case responsibility split](#canonical-use-case-responsibility-split); keep `ActionController` types out of Interactors).
2. Instantiate API presenter (output port implementation): `presenter = PresenterClass.new(view: self)`.
3. Instantiate gateway(s) from `CompositionRoot`.
4. `InteractorClass.new(output_port: presenter, gateway: gw, ...).call(input_dto)`. For [composite use cases](#composite-use-cases-and-input-port-injection), also `build_*_interactor(output_port:)` for each sub-step and inject as Input port (and collector if needed).
5. Let the interactor finish through the **output port** for both success and modeled failures-do not wrap `interactor.call` in `rescue` for those paths.


AI-specific endpoints (`ai_create`, etc.) follow this checklist; they are not special cases for layering.

#### Canonical use-case responsibility split

Normative end-to-end flow for JSON and HTML actions. Extends the [Checklist](#checklist) with **where mapping happens** at each boundary (including **Controller → Interactor**).

```mermaid
sequenceDiagram
  participant Ctrl as Controller
  participant ReqMap as Request_mapper_adapter
  participant Int as Interactor
  participant Gw as Gateway_adapter
  participant Pol as Policy_pure
  participant DMap as Domain_mapper
  participant Port as Output_port
  participant Pres as Presenter
  participant AMap as Adapter_mapper

  Ctrl->>ReqMap: params or request
  ReqMap-->>Ctrl: Input DTO
  Ctrl->>Int: call(input_dto)
  Int->>Gw: find list count
  Gw-->>Int: Entity or Snapshot
  Int->>Pol: scalars attributes only
  Pol-->>Int: allow or deny
  Int->>Gw: create update delete
  Int->>DMap: combine Snapshots
  DMap-->>Int: Output DTO
  Int->>Port: on_success on_failure
  Port->>AMap: Output DTO
  AMap-->>Pres: JSON Hash etc
  Pres->>Ctrl: render_response
```

| Layer | Does | Does not |
|---|---|---|
| **Controller** | Wire presenter and gateways from `CompositionRoot`; invoke request mapper; `interactor.call(input_dto)` | Business rules; gateway I/O; `{ kind: }` outcome branching; AR queries for use-case data |
| **Request mapper** (adapter) | `params` / `ActionController::Parameters` → `<Usecase>Input` (types, coercion, nesting). See placement below | Policy; gateway; authorization; business rules; I/O |
| **Interactor** | Gateway order: read → Policy → write → domain mapper → output port | Pass gateway into Policy; read raw `params`; ActiveRecord; `{ kind: }` switches for modeled outcomes |
| **Policy** | Decide from passed values only | Gateway; `find` / `count`; ActiveRecord ([R0](#r0-authorization-and-validation)) |
| **Gateway** | Five-verb I/O; adapter maps AR → **domain read snapshot** at the boundary ([Gateway Boundary](#gateway-boundary)) | Authorization; rules; `{ kind: }`; presenter-shaped composites; adapter-only intermediate types to Interactor |
| **Domain mapper** | Combine **snapshots** → output DTO via `from_snapshots` ([Mappers](#mappers)) | I/O; adapter types |
| **Presenter + adapter mapper** | Output DTO → HTTP status / JSON / view shape | Gateway calls; load data for the use case |

**Request mapper placement (Controller → Interactor):**

- Prefer `app/adapters/<context>/presenters/forms/<usecase>_form.rb` for typical CRUD `params` → `<Usecase>Input` ([Presenter-side helpers](#presenter-side-helpers-forms--view-models) — Form row).
- Use `app/adapters/<context>/mappers/` modules (e.g. `AdjustMovesFromRequest`) when normalization is shared, not form-shaped, or reused across controllers.
- Inline `Input.new(...)` in the controller is acceptable only for **trivial** mapping (no coercion, no nested structure, no duplication). Extract to Form or request mapper when types, nesting, or reuse appear.

**Reference implementations:**

| Step | Example |
|---|---|
| Request mapper | `Adapters::CultivationPlan::AdjustMovesFromRequest` → `PlanAllocationAdjustInput` in `CultivationPlanRestBaseController#adjust` |
| REST adjust | `CompositionRoot.build_plan_allocation_adjust_interactor(output_port: PlanAllocationAdjustApiPresenter)` + `PlanAllocationAdjustInput`（`auth` あり） |
| REST add_crop | `build_add_crop_crop_resolve(auth:)` → `AddCropCropResolveInputPort`；`build_plan_allocation_adjust_interactor(output_port: AddCropAdjustResultCollector)` を `PlanAllocationAdjustInputPort` として注入 |
| Input port nesting | `PlanAllocationAdjustInputPort` + `build_plan_allocation_adjust_interactor` — see [Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection) |
| REST add_crop (orchestrator) | `AddCropInteractor` + `AddCropCropResolveInputPort` + `PlanAllocationAdjustInputPort` + `AddCropAdjustResultCollector` |
| Orchestration + pure Policy | `CropCreateInteractor` + `CropCreateLimitPolicy` (Interactor calls `gateway.count`; Policy receives counts only) |
| PlanSave persist step (farm) | `PlanSaveEnsureUserFarmInteractor` + `FarmCreateLimitPolicy` + `PlanSaveFarmGateway`（戻り値 `PlanSaveReferenceFarmSnapshot` / `PlanSaveUserFarmSnapshot`；`find_owned_private_plan_record` — not `find_private_*` in the method name） |
| PlanSave persist step (field) | `PlanSaveEnsureUserFieldsInteractor` + `PlanSaveFieldGateway`（`list_by_farm_id` / `create`；戻り値 `PlanSaveFieldSnapshot`）；template-copy は `PlanSaveTemplateCopyIntegrity#field_records_for_template_copy`（`user_id` でスコープ） |
| PlanSave persist step (crop / pest) | `PlanSaveEnsureUserCropsInteractor` / `PlanSaveEnsureUserPestsInteractor` + `PublicPlanSaveReadGateway` 行 DTO + `PlanSaveUserCropGateway` / `PlanSaveUserPestGateway`（find/create のみ；戻り値 `PlanSaveUserCropSnapshot` / `PlanSaveUserPestSnapshot`；template-copy 手渡しは `PlanSaveTemplateCopyIntegrity#crop_records_for_template_copy` / `#pest_records_for_template_copy`） |
| PlanSave persist step (fertilize) | `PlanSaveEnsureUserFertilizesInteractor` + `PublicPlanSaveReadGateway`（`list_fertilize_reference_rows` / `exists_fertilize_name?`）+ `PlanSaveUserFertilizeGateway`（find/create のみ；戻り値 `PlanSaveUserFertilizeSnapshot`；template-copy 手渡しは `PlanSaveTemplateCopyIntegrity#fertilize_records_for_template_copy` — domain gateway に `list_by_ids` なし） |
| PlanSave persist step (pesticide) | `PlanSaveEnsureUserPesticidesInteractor` + `PublicPlanSaveReadGateway`（`list_pesticide_reference_rows`）+ `PlanSaveUserPesticideGateway`（`find_by_*` / `create` と optional 子 kwargs のみ；戻り値 `PlanSaveUserPesticideSnapshot`；template-copy は `PlanSaveTemplateCopyIntegrity#pesticide_records_for_template_copy`） |
| PlanSave persist step (agricultural_task) | `PlanSaveEnsureUserAgriculturalTasksInteractor` + `PublicPlanSaveReadGateway`（`list_agricultural_task_reference_rows`）+ `PlanSaveUserAgriculturalTaskGateway`（find/create + `find_crop_task_template` / `create_crop_task_template`；戻り値 `PlanSaveUserAgriculturalTaskSnapshot`；template-copy は `PlanSaveTemplateCopyIntegrity#agricultural_task_records_for_template_copy` — `user_id` でスコープ） |
| PlanSave persist step (interaction_rule) | `PlanSaveEnsureUserInteractionRulesInteractor` + `PublicPlanSaveReadGateway`（`list_interaction_rule_reference_rows`）+ `PlanSaveUserInteractionRuleGateway`（`find_by_*` / `create` / `update`；戻り値 `PlanSaveUserInteractionRuleSnapshot`；template-copy は `PlanSaveTemplateCopyIntegrity#interaction_rule_records_for_template_copy` — `user_id` でスコープ） |
| Domain combine | `CultivationPlanWorkbenchSnapshotMapper` (read snapshots → `CultivationPlanWorkbenchSnapshot`) |
| Response shape | `RetrieveCultivationPlanApiPresenter` + `CultivationPlanWorkbenchPayloadMapper` (adapter mapper only) |

#### Layout example (reference implementation)

**DTO (input)** → **gateway interface** → **interactor** → **output port** (implemented by Presenter) → **adapter gateway** → `CompositionRoot`. **Example:** CRUD under `app/controllers/api/v1/masters/farms_controller.rb` (e.g. `create`) with `lib/domain/farm/interactors/farm_create_interactor.rb`, `app/adapters/farm/presenters/farm_create_api_presenter.rb`, `app/adapters/farm/gateways/farm_active_record_gateway.rb`, and `CompositionRoot.farm_gateway`.


### Domain Modules

Domain modules live under `lib/domain/`.

Each bounded context typically has: `entities/`, `dtos/`, `gateways/` (interfaces), `interactors/`, `policies/` (intrinsic validation rules; extrinsic validation rules **are defined here**, Interactors fetch data via gateways and pass to Policies for validation), `ports/` (**output ports** for interactors; **input ports** for sibling sub-steps — see [Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection)), and `mappers/` (**domain mappers** — pure DTO/Entity transformations; created as needed). Infrastructure ports (logger, clock, translator, etc.) live under `lib/domain/shared/ports/`. Cross-context gateways that exchange entities/DTOs (e.g. `UserLookupGateway`) live under `lib/domain/shared/gateways/`.

Source of truth: the directory listing of `lib/domain/`. When adding a new bounded context, create the standard subdirectory structure under `lib/domain/<context>/` as described in [Domain Modules](#domain-modules).

### Adapters

Adapters live under `app/adapters/<context>/`.

Framework-dependent adapter code (gateway implementations, presenters, and presenter-side helpers) lives under **`app/adapters/<context>/`**, autoloaded by Zeitwerk. The pure domain in `lib/domain/<context>/` stays Rails-agnostic.

- `app/adapters/<context>/gateways/` - gateway interface implementations (ActiveRecord, in-memory for tests, HTTP, CLI, ActionCable, ActiveJob, ...).
- `app/adapters/<context>/presenters/` - output port implementations; see [Presenters](#presenters) for the full subtree (forms / view_models).
- `app/adapters/<context>/mappers/` - Domain output → JSON Hash / display shape. See [Mappers](#mappers).
- `app/adapters/agrr/gateways/` - external agrr daemon clients (cross-context infrastructure).
- `app/adapters/shared/ports/` - infrastructure port adapters (logger, clock, translator, mailer transport, etc.).

Legacy locations (`lib/adapters/<context>/`, `lib/presenters/`, `app/gateways/agrr/`) have been migrated to the layout above. **New code uses the canonical paths only.**

File-name and method-name rules are in [Naming and placement conventions](#naming-and-placement-conventions) below.

### Gateway Boundary

Gateways **must not** depend on HTTP or incidental UI conventions: shapes named for a specific template/partials; Hash layouts driven by `data-`* attributes or route-helper-only keying; or return types / method naming that encode a **screen identifier** (`*_page`, `*_html`, etc.) when the real intent is **view/SPA-specific key arrangement** assembled inside the persistence adapter.

**Heuristic:** If the gateway's job is effectively "produce the blob this one HTML partial or Angular screen expects," the boundary is wrong-lift assembly to the **Interactor** or to a domain **mapper** under `lib/domain/<context>/mappers/` (read snapshots → **output-port DTOs** / use-case payloads; **not** HTTP-aware types).

**Allowed:** Persistence operations and **domain-meaningful read snapshots** as DTOs or value objects (IDs, dates, counts, cultivated rows, etc.). Gateways may accept identity-bound filters as input parameters (e.g. `find_by_user_id(user_id)`), but do not make authorization or validation decisions. See [R0](#r0-authorization-and-validation). **Presenter-shaped** composites required by an output port (for example `PrivatePlanShowOutput`) are composed **outside** the gateway adapter — in the **Interactor** or a domain **mapper** under `lib/domain/<context>/mappers/`.

**Decision boundary:** Gateway methods are narrow persistence / HTTP / process I/O. Cross-context orchestration, multi-step business flow, authorization and validation decisions follow [R0](#r0-authorization-and-validation). Examples on the wrong side of the boundary include authorization encoded as a scope chooser (`scope_for_admin_or_user`, `is_admin ? A.where(...) : B.where(...)`), role-aware visibility filters, conditional dispatch across multiple I/O calls, uniqueness checks, resource limit checks, and methods that bundle several persistence operations into a single use-case-encoding entry point. A gateway that returns different domain shapes depending on caller identity has crossed the boundary.

#### Read snapshot assembly: domain composes, adapter does narrow I/O

When moving **thick adapter assembly** (parent + child loaded and merged in one gateway) into the domain, the target shape is **not** “one gateway returns the screen blob.” It is:

| Layer | Responsibility |
|---|---|
| **Interactor** | Calls **separate gateway interfaces** per table/aggregate (parent gateway, child gateway, …); runs Policy; decides call order. Receives **`lib/domain` read snapshots only**. Invokes a **domain mapper** to combine snapshots into the output-port DTO. |
| **Gateway interface** (`lib/domain/.../gateways/`) | Return type is a **read snapshot** DTO under `lib/domain/<context>/dtos/*_snapshot.rb` (or a list of them). |
| **Adapter gateway** | Narrow I/O for **one table** per method; maps AR → **domain read snapshot** before returning to the Interactor. Does not return presenter-shaped composites. |
| **Adapter snapshot mapper** (`app/adapters/.../mappers/*_snapshot_mapper.rb`) | AR → **domain read snapshot** (one table per mapper). Runs **inside** the adapter gateway implementation only. |
| **Adapter preload** | May batch rows for performance, but **must not** merge parent and child into a use-case output. Do not use `includes(:child)` solely to assemble a screen blob in the adapter. |
| **Domain mapper** (`lib/domain/.../mappers/`) | Pure combine: `from_snapshots(parent_snapshot:, child_snapshots:, …)` or snapshot → output-port DTO. **No I/O**, no adapter types. |

**Read snapshot (normative):**

- **Read snapshot** — domain-meaningful DTO in `lib/domain/<context>/dtos/*_snapshot.rb`; the only shape gateways return to Interactors.
- **Re-map in domain:** Parent and child are fetched in **separate** Interactor → gateway calls; each returns its own snapshot. A **domain mapper** then combines them (`from_snapshots`, not a single gateway blob).
- **No intermediate adapter DTO for reads:** Do not introduce AR→adapter-wire→snapshot chains; **AR → domain read snapshot** in the gateway implementation is sufficient.

**Anti-patterns (forbidden for new code):**

- One preload with `includes(:children)`, nested adapter-only DTOs, gateway returning output-port-shaped DTO (e.g. thick `find_show_detail` in a persistence gateway).
- Gateway interface or Interactor methods named `*_wire_*` or domain mappers `from_wire`.
- Extra adapter mapping stages between AR and the domain read snapshot when a single snapshot mapper suffices.

**Reference (target):** separate gateway calls returning `FieldCultivationPlanAccessSnapshot` / `FieldCultivationClimateSourceSnapshot` / `FieldCultivationApiSummarySnapshot` (adapter: `FieldCultivationClimateSourceSnapshotMapper`, `FieldCultivationApiSummarySnapshotMapper`); domain `FieldCultivationApiSummaryMapper.from_snapshot` for output DTO. **REST plan read (target):** `plan_gateway.find_by_id` → Policy → `rest_plan_read_gateway` (per-table narrow reads) → domain `CultivationPlanRestPlanSnapshotMapper.load_snapshot` → `available_crop_rows_gateway.list_by_farm_region` → `CultivationPlanWorkbenchSnapshotMapper.from_snapshots`.

##### Anti-pattern: thick adapter assembly

```mermaid
sequenceDiagram
  autonumber
  participant Ctrl as Controller
  participant Int as Interactor
  participant GW as Gateway adapter
  participant Pre as Preload
  participant AR as ActiveRecord
  participant Wire as Wire mapper parent+child
  participant DomMap as Domain mapper
  participant Port as Output port

  Ctrl->>Int: call(parent_id)
  Note over Int: Interactor calls gateway once

  Int->>GW: find_show_detail(id)
  GW->>Pre: find!(id)
  Pre->>AR: Parent.includes(:children).find(id)
  Note over AR,Pre: Parent and child tables fetched together

  AR-->>Pre: AR graph with children
  Pre-->>GW: AR graph
  GW->>Wire: from_model(parent)
  Note over Wire: One mapper maps parent and child columns into nested wire

  Wire-->>GW: ParentWire with nested children
  GW->>DomMap: from_wire(wire)
  Note over DomMap: Wire or from_wire in lib/domain forbidden
  DomMap-->>GW: UseCaseOutput
  GW-->>Int: UseCaseOutput
  Int->>Port: on_success(dto)
```

##### Target: domain composes via separate gateways (snapshots only)

```mermaid
sequenceDiagram
  autonumber
  participant Ctrl as Controller
  participant Int as Interactor
  participant PGW as ParentGateway IF
  participant CGW as ChildGateway IF
  participant AP as Parent AR gateway impl
  participant AC as Child AR gateway impl
  participant PS as Parent snapshot mapper app
  participant CS as Child snapshot mapper app
  participant DomMap as Domain mapper
  participant Port as Output port

  Ctrl->>Int: call(auth, parent_id)

  Note over Int: Policy in domain only

  Int->>PGW: find_snapshot(parent_id)
  PGW->>AP: find parent row only
  AP->>PS: from_model(parent row)
  PS-->>PGW: ParentSnapshot
  PGW-->>Int: ParentSnapshot

  Int->>CGW: list_snapshots_by_parent_id(parent_id)
  CGW->>AC: list child rows only
  AC->>CS: from_models(child rows)
  CS-->>CGW: ChildSnapshot[]
  CGW-->>Int: ChildSnapshot[]

  Note over Int,DomMap: Interactor sees domain read snapshots only

  Int->>DomMap: from_snapshots(parent, children)
  DomMap-->>Int: UseCaseOutput
  Int->>Port: on_success(dto)
```

##### Responsibility by layer (compact)

```mermaid
sequenceDiagram
  box rgb(255,240,240) app/adapters I/O
    participant GW_P as Parent gateway impl
    participant GW_C as Child gateway impl
    participant S_P as Parent snapshot mapper
    participant S_C as Child snapshot mapper
  end
  box rgb(240,255,240) lib/domain snapshots and assembly
    participant Int as Interactor
    participant Pol as Policy
    participant M as Domain mapper
  end

  Int->>GW_P: find_snapshot(parent_id)
  GW_P->>S_P: from_model(parent row)
  S_P-->>Int: ParentSnapshot

  Int->>Pol: allowed?(parent, auth)
  Pol-->>Int: ok or deny

  Int->>GW_C: list_snapshots_by_parent_id(parent_id)
  GW_C->>S_C: from_models(child rows)
  S_C-->>Int: ChildSnapshot[]

  Int->>M: from_snapshots(parent, children)
  M-->>Int: UseCaseOutput DTO
```

| | Thick adapter assembly | Domain assembly (required for new reads) |
|---|---|---|
| Interactor → gateway | One call | Parent gateway + child gateway + … |
| SQL / preload | `includes(children)` in adapter | Table-scoped narrow read per gateway |
| Adapter mapping | One mapper, multiple tables / nested adapter DTO | **One snapshot mapper per table** (AR → domain read snapshot) |
| Type crossing into Interactor | Adapter-only DTO or output DTO from gateway | **`lib/domain` read snapshot** per call |
| Parent/child merge | Adapter (gateway return value) | **Domain mapper `from_snapshots`** after separate fetches |
| Domain mapper input | Adapter types or `from_wire` | **`from_snapshots`** / snapshot → output DTO |
| Gateway return | Near presenter/output-port shape | Domain read snapshot per table |

### Gateway injection

Gateways are constructor-injected into Interactors from `CompositionRoot`. The keyword argument name reflects the gateway's role in the interactor (e.g. `farm_gateway:`, `deletion_undo_gateway:`). Interactors receive gateway instances — they never instantiate or locate gateways internally. When a use case requires multiple gateways, all are passed at construction time.

Interactor constructor signatures **must** explicitly list all required gateways and **Input ports** as keyword arguments, mirroring the `output_port:` convention already established for Presenters. This makes the dependency graph visible at the call site and simplifies test wiring ([Testing](#testing)).

**Sibling sub-steps** (another Interactor inside the same user-facing use case) use [Input port injection](#composite-use-cases-and-input-port-injection), not extra gateways and not `CompositionRoot` inside adapters.

### Composite use cases and Input port injection

When one user-facing use case must run another use case as an orchestrated **sub-step** in the same HTTP action (e.g. add crop, then adjust allocation), compose with **Input port injection** — this is the approved form of **Interactor nesting**.

#### Pattern (required for new sub-steps)

1. **Input port** — `lib/domain/<context>/ports/<sub_step>_input_port.rb` declares `call(<SubStep>Input)`.
2. **Sub-step Interactor** — `class <SubStep>Interactor < <SubStep>InputPort` implements the port; uses gateways and its own `output_port` (constructor).
3. **Edge build** — controller/job calls `CompositionRoot.build_<sub_step>_interactor(output_port: ...)` once per invocation. Each build gets a **fresh** `output_port` (API Presenter, or an adapter collector for orchestrator consumption).
4. **Orchestrator** — receives the built instance as a constructor dependency typed as the **Input port** (e.g. `plan_allocation_adjust:`), and calls `@plan_allocation_adjust.call(input)` only through that interface.
5. **Sub-step results** — when the orchestrator must branch on success/failure, pass the same collector used as `output_port` (e.g. `add_crop_adjust_result_sink:`) or map sub-step output DTOs in the orchestrator. Do not reuse the orchestrator's HTTP Presenter as the sub-step `output_port`.

```mermaid
flowchart LR
  Ctrl[Controller job]
  Orch[Orchestrator Interactor]
  IP[SubStep InputPort]
  Sub[SubStep Interactor]
  Col[SubStep output_port collector or Presenter]
  Build[CompositionRoot build_sub_step_interactor]

  Ctrl --> Build
  Build -->|output_port| Sub
  Ctrl -->|inject port impl| Orch
  Ctrl -->|optional same collector| Orch
  Orch -->|call input| IP
  Sub -.->|implements| IP
  Sub -->|on_success on_failure| Col
  Orch -->|read result| Col
```

#### What is allowed

| Mechanism | Use |
|---|---|
| **Gateways** | Persistence / I/O within a single Interactor |
| **Input port → sub-step Interactor** | Same bounded context; sub-step built at edge via `build_*_interactor` |
| **Injected callable on sub-step** | Edge-only mappers (e.g. `agrr_adjust_result_sync_mapper:` on `PlanAllocationAdjustInteractor`). **New** inner steps exposed to another Interactor use an Input port (e.g. `FieldCultivationSyncInputPort`) |
| **One orchestrator `call` per HTTP action** | Controller calls the top-level Interactor once; rollback/compensation stays inside it |

#### What is forbidden

| Anti-pattern | Why |
|---|---|
| `CompositionRoot.*` in `lib/domain` or in adapters (host/bridge wrappers) | Service locator; violates R1/R4 |
| Orchestrator `new`ing sub-step Interactor or holding `*InteractorFactory` | Wiring belongs at edge |
| Orchestrator depending on concrete sub-step Interactor class instead of Input port | Hides substitution in tests; couples layers |
| **Presenter / Form / ViewModel** calling any `Interactor#call` | R6 — display layer does not run use cases |
| Controller calling **two top-level** interactors when one orchestrator should own rollback | Splits compensation across HTTP edge |
| Sharing one `output_port` instance between orchestrator HTTP response and sub-step without a deliberate collector contract | Collides Presenter with sub-step callbacks |

#### Unit of work (clarified)

- **User-facing use case** — one controller/job action ⇒ **one** top-level `Interactor#call` ⇒ **one** output port for the HTTP/HTML response (the Presenter).
- **Sub-step** — each `#call` on an Input port is a **nested** interactors execution with a **separate** `output_port` chosen at build time; it does **not** create a second user-facing use case or a second controller action.
- **Standalone sub-step API** (e.g. REST `adjust` only) — same sub-step Interactor, different `output_port` at build time (API Presenter instead of collector).

#### Reference implementations

| Case | Wiring |
|---|---|
| REST `adjust` | `build_plan_allocation_adjust_interactor(output_port: PlanAllocationAdjustApiPresenter)` |
| REST `add_crop` | `build_add_crop_crop_resolve(auth:)` + `build_plan_allocation_adjust_interactor(output_port: AddCropAdjustResultCollector)` injected into `AddCropInteractor` |
| Inner sync after adjust | `PlanAllocationAdjustInteractor` + `FieldCultivationSyncInputPort` + edge `AgrrAdjustResultFieldCultivationSyncMapper` |

### Presenters

Presenters live under `app/adapters/<context>/presenters/`.

- **API JSON:** `app/adapters/<context>/presenters/<usecase>_api_presenter.rb` - implements the domain output port and calls `view.render_response(json:, status:)`.
- **HTML (Rails views):** `app/adapters/<context>/presenters/<usecase>_html_presenter.rb` - same output port; performs `redirect_to` / `render` instead of JSON.

**Rule:** New presenters belong under `app/adapters/<context>/presenters/`. The legacy locations (`app/presenters/`, `lib/presenters/`) are retired.

#### Presenter-side helpers (forms / view models)

The Presenter itself stays thin: it implements the output port (`on_success` / `on_failure`) and delegates shape work to the helpers below. Each helper is a **Plain Ruby object** - no `ActiveModel::Model`, no callbacks, no Rails magic, no I/O of its own.

| Helper | Path | Direction | Mutability | Responsibility |
|---|---|---|---|---|
| **Form** | `app/adapters/<context>/presenters/forms/<usecase>_form.rb` | params → `<Usecase>Input` (write) | mutable (survives `on_failure` re-render) | **Request mapper** at the HTTP edge: params → Input DTO (type coercion, defaults). No validation, no authorization, no business rules, no gateway calls. See [Canonical use-case responsibility split](#canonical-use-case-responsibility-split) |
| **ViewModel** | `app/adapters/<context>/presenters/view_models/<usecase>_view_model.rb` | `<Usecase>Output` → display (read) | immutable | formatted dates, derived labels, URLs, CSS classes; nothing that needs a gateway |

**Why this split:** domain output DTOs are use-case-neutral - they encode *what the use case produced*, not *what the screen needs*. Form / ViewModel are where screen / API shape lives, so that `lib/domain/` does not grow per-screen variants like `*_read_model.rb` or `*_payload_dto.rb`.

**Boundary:** Presenters implement output ports only (shape HTTP from success/failure payloads). For JSON actions, **modeled outcomes** follow the [Checklist](#checklist). No presenter fetch via `CompositionRoot` / `find_model` / gateways; no business rules in presenters. Load in the **Interactor** via gateways; pass **DTOs/entities** on the port. Do not hide `find_model` or gateway calls in **controller-local procs/lambdas** passed into the presenter. `lib/domain` does not reference `Rails.`*; inject from the **composition root at the app edge** (controller/job), not framework singletons.

#### Output Port Contract

The output port is the contract for transmitting use-case success/failure via DTOs. See [R5](#r5-output-port-contract), [R6](#r6-display-only), [R10](#r10-implementation-order-and-definition-of-done) for details.

**Refactoring summary:**

- **Before:** "Remove presenter service location and push load toward the Interactor."
- **After:** "Fix the **output port contract** on **DTOs/entities**; the **Interactor** satisfies it using **gateways only**. Presenters **map for display only**; where templates assumed AR, update templates to **DTO-first** in the same scope - **do not reintroduce AR via presenters or controller-embedded fetch procs.**"

### Mappers

Mappers are **Plain Ruby objects** that perform pure type transformations. They are used in **three** roles along the use-case path ([Canonical use-case responsibility split](#canonical-use-case-responsibility-split)):

- **Request mappers** (`app/adapters/<context>/mappers/` or `app/adapters/<context>/presenters/forms/`) — Called by **Controllers** at the HTTP edge. `params` / request → `<Usecase>Input`. **No I/O**, no Policy, no gateway. Keeps `ActionController::Parameters` and strong-params details out of Interactors. Forms are the default request mapper for write flows; standalone mapper modules suit shared or non-form normalization (e.g. `AdjustMovesFromRequest`).
- **Domain mappers** (`lib/domain/<context>/mappers/`) — Called by **Interactors**. Entity ↔ DTO, snapshot ↔ DTO, DTO ↔ DTO; combine read snapshots via `from_snapshots` ([Read snapshot assembly](#read-snapshot-assembly-domain-composes-adapter-does-narrow-io)). **No I/O**, no Gateway/Policy calls, no adapter types. Extract to mapper even for simple field copying; do not inline conversion inside Interactors.
- **Adapter mappers** (`app/adapters/<context>/mappers/`) — **Snapshot mappers** (AR → `lib/domain` read snapshot; inside gateway implementations) and **response mappers** (called by Presenters: domain output → JSON Hash / HTML display shape).

**Rule:** `lib/domain/<context>/assemblers/` is not allowed. Composition must be handled within Interactors or through domain mappers.

**Naming:**
- **Request mapper (module)**: `app/adapters/<context>/mappers/<name>_from_request.rb` or descriptive module name — e.g. `Adapters::CultivationPlan::AdjustMovesFromRequest`
- **Request mapper (Form)**: `app/adapters/<context>/presenters/forms/<usecase>_form.rb` — `Adapters::<Context>::Presenters::Forms::<Usecase>Form`
- **Domain mapper**: `lib/domain/<context>/mappers/<name>_mapper.rb` — `Domain::<Context>::Mappers::<Name>Mapper`
- **Adapter mapper (response)**: `app/adapters/<context>/mappers/<name>_mapper.rb` — `Adapters::<Context>::Mappers::<Name>Mapper`

**Boundary:** Mappers perform pure transformations only. No business rules, authorization decisions, or I/O. Request mappers: HTTP-shaped input → Input DTO. Domain mappers: DTOs, Entities, Snapshots only. Adapter response mappers: domain port payloads → HTTP/view shape.

### Naming and placement conventions

These conventions apply to all new code.

#### Port or Gateway?

The framework-dependent layer distinguishes two roles:

- **Gateway** (`<context>/gateways/`) - operations that take input **and** return *domain entities / DTOs / snapshots*, mediating persistence or external systems (DB, HTTP, daemon, ActionCable, ActiveJob). Bound to a domain context.
- **Infrastructure Port** (interface in `lib/domain/shared/ports/`, impl in `app/adapters/shared/ports/<name>_<tech>_adapter.rb`) - one-way framework / driver outputs that do **not** exchange entities: logger, translator, clock, mailer transport, metrics sink. Typically cross-cutting; the "context" name is synthetic (e.g. `shared`).

- **Output port** (interface in `lib/domain/<context>/ports/`, impl in `app/adapters/<context>/presenters/`) - defines the callback shape (`on_success` / `on_failure` and DTOs) for a use case. Presenters implement this contract. Bound to a domain context.

**Rule of thumb**: if the abstraction is **bidirectional** (takes input AND returns entities/DTOs) → Gateway. If it is **one-way** (callback or driver output) → Port. New cross-cutting framework abstractions (clock, mailer transport, metrics sink) follow the port convention, not the gateway convention.

#### Gateway file naming

| File | Path | Class |
|---|---|---|
| Interface | `lib/domain/<context>/gateways/<name>_gateway.rb` | `Domain::<Context>::Gateways::<Name>Gateway` |
| ActiveRecord impl. | `app/adapters/<context>/gateways/<name>_active_record_gateway.rb` | `Adapters::<Context>::Gateways::<Name>ActiveRecordGateway` |
| In-memory impl. | `app/adapters/<context>/gateways/<name>_memory_gateway.rb` | `...<Name>MemoryGateway` |
| HTTP impl. | `app/adapters/<context>/gateways/<name>_http_gateway.rb` | `...<Name>HttpGateway` |
| CLI / process impl. | `app/adapters/<context>/gateways/<name>_cli_gateway.rb` | `...<Name>CliGateway` |
| ActionCable impl. | `app/adapters/<context>/gateways/<name>_action_cable_gateway.rb` | `...<Name>ActionCableGateway` |
| ActiveJob impl. | `app/adapters/<context>/gateways/<name>_active_job_gateway.rb` | `...<Name>ActiveJobGateway` |
| agrr daemon impl. | `app/adapters/agrr/gateways/<name>_daemon_gateway.rb` | `Adapters::Agrr::Gateways::<Name>DaemonGateway` |

**Allowed adapter-type suffixes are fixed at seven** - `_active_record_gateway`, `_http_gateway`, `_cli_gateway`, `_daemon_gateway`, `_memory_gateway`, `_action_cable_gateway`, `_active_job_gateway`. Object-storage backends (GCS / S3) are treated as `_http_gateway` (the I/O category); the specific SDK / bucket is an implementation detail injected into the adapter, not encoded in the file name. Do not add new adapter-type suffixes without an ADR.

**Disallowed suffixes**: `_gateway_adapter`, `_active_gateway` (always spell out `_active_record_gateway`), `_through_host_gateway` as the adapter type (it names a workflow - rename to the actual adapter), and unqualified `*_gateway.rb` inside `app/adapters/<context>/gateways/` without an adapter type.

**Disallowed infixes**: presentation channel names like `*_rest_*_gateway.rb`, `*_html_*_gateway.rb`, `*_json_*_gateway.rb`. Gateways are presentation-agnostic; an "adjust" gateway is the same whether the request arrives via REST, HTML form, or background job.

#### Port file naming

| File | Path | Class |
|---|---|---|
| Interface | `lib/domain/shared/ports/<name>_port.rb` | `Domain::Shared::Ports::<Name>Port` |
| Adapter impl. | `app/adapters/shared/ports/<name>_<tech>_adapter.rb` | `Adapters::Shared::Ports::<Name><Tech>Adapter` |

Example: `Domain::Shared::Ports::LoggerPort` (interface) ↔ `Adapters::Shared::Ports::RailsLoggerAdapter` at `app/adapters/shared/ports/rails_logger_adapter.rb`. Ports are file-named with the `_adapter` suffix - distinct from gateways - because they emit one-way to a framework driver rather than mediating entity I/O.

**`ClockPort`** (`lib/domain/shared/ports/clock_port.rb`) — inject from the edge; Interactors must not call `Date.current` / `Time.current` / `Time.zone` directly ([R1](#r1-framework-free)).

| Method | Use |
|---|---|
| `today` | Calendar date in the app time zone (e.g. planning windows, `as_of`) |
| `now` | Current time for timestamps (e.g. copy suffixes, `rescheduled_at`, performance markers) |

Implementation: `Adapters::Shared::Ports::RailsClockAdapter` (`Time.zone.today` / `Time.zone.now`).

#### Gateway method naming (the five verbs)

| Verb | Return | Use |
|---|---|---|
| `find_by_*(criteria)` | `Entity \| nil` | Read one entity. Criteria must be a scalar or identity **field** (e.g. `find_by_id`, `find_by_token`, `find_by_user_id`). Entity name is never encoded in the method name |
| `list_by_*(criteria)` | `Array<Entity>` | Read multiple entities. Criteria must be a scalar or identity **field** (e.g. `list_by_user_id`, `list_by_status`). Entity name is never encoded in the method name |
| `create(...)` | persisted entity | Insert a new entity. `save` is deprecated; unify to `create`/`update` within the bounded context. |
| `update(...)` | persisted entity | Modify an existing entity. `save` is deprecated; unify to `create`/`update` within the bounded context. |
| `delete(id)` | result | Permanent delete. `destroy` is deprecated; unify to `delete` within the bounded context. |

**The gateway only filters by the given criteria**; authorization and validation follow [R0](#r0-authorization-and-validation). Soft delete is the dedicated method `soft_delete_with_undo(id, user)`.

**Allowed exceptions:**
- `get_<state>` - *narrow, non-entity* scalar getter (progress percentage, fetched-year list). Never for entities.
- `fetch_*` - only for external HTTP / process I/O (e.g. `fetch_historical_weather_data` from a remote API). Not for DB reads.
- `upsert_*` - when both insert and update are explicit semantics for one operation.
- `sync_by_*(criteria)` — replace a **child collection** under the criteria (e.g. `sync_by_plan_id(plan_id:, sync_apply:)`) in one transaction. Criteria is the parent scope only. Interactor builds `*PlanSnapshot` (current) + `*TargetSnapshot` (desired) via domain mappers, diffs to `*SyncApply`, gateway applies it.
- `soft_delete_with_undo(id, user)` - dedicated soft-delete method. Not a replacement for `delete(id)`.
- `count_by_*(criteria)` → `Integer` — identity-scoped **row count** for Interactor → Policy scalar pass-through (resource limits). Prefer `count_by_user_id(user_id:)` over loading rows. Existing gateways may use `count_<description>` (e.g. `count_user_owned_non_reference_farms`); new methods follow `count_by_*`.
- **Related entity retrieval** — The five verbs (`find_by_*`, `list_by_*`, `create`, `update`, `delete`) may be used to load entities associated with another entity, as long as the entity name is not encoded in the method. The criteria expresses the relationship, not the target entity type.

  | ✅ Allowed | ❌ Disallowed | Reason |
  |---|---|---|
  | `list_by_farm_id(farm_id)` → crops | `list_crops_by_farm_id(farm_id)` | Entity name (`crops`) must not appear in method |
  | `find_by_crop_id(crop_id)` → crop's farm | `find_farm_by_crop_id(crop_id)` | Entity name (`farm`) must not appear in method |
  | `list_by_user_id(user_id)` → user's farms | `list_farms_by_user_id(user_id)` | Entity name (`farms`) must not appear in method |

  The gateway returns its own entity type; the Interactor decides what the result represents in the use-case context.

**Disallowed**: `get_<entity>(id)`, `load_<entity>(id)`, `find_<entity>_by_<criteria>`, `list_<entity>_by_<criteria>`, `query_*`, `by_*` as the whole method name, DB reads under `fetch_*`, using both `save` and `create`/`update` for the same write operation. Use-case-encoding names such as `create_user_farm_from_reference` — prefer `create(...)` with explicit keyword arguments.

#### Disallowed gateway public method name patterns

Normative list for **new** adapter gateway public methods. [`test/architecture/gateway_public_method_naming_test.rb`](../test/architecture/gateway_public_method_naming_test.rb) enforces the same patterns (do not maintain a second list elsewhere).

| Pattern (regex) | Why |
|---|---|
| `\Ainitialize_plan` | Use-case initialization belongs in Interactor |
| `\Afind_private_` | Encodes authorization path; Interactor chooses `find_by_*` + criteria (e.g. `plan_type` in SQL), not method name |
| `\Afind_.*_bundle` | Presenter-shaped / multi-entity bundle |
| `\Afind_or_create_` | Orchestration in Interactor |
| `\Asave_adjust_result!` | Use-case save in Interactor |
| `\Aapply_field_cultivations` | Use-case mutation in Interactor |
| `\Acopy_for_user_crops` / `\Acopy_reference_stages` | Multi-step copy in Interactor |
| `\Aagrr_rules_for_cultivation_plan_id` | Rule assembly in domain |
| `\Aoptimization_plan_snapshot` / `\Atask_schedule_timeline_snapshot` / `\Aprivate_plan_index_plan_rows` | Screen/use-case snapshot in Interactor + domain mapper |
| `\Alink_pest_to_crop` / `\Aupdate_pest_crop_associations` | Association rules in Interactor |

**Policy / domain** methods (e.g. `PrivateCultivationPlanAccessPolicy.assert_private_owned!`) are not gateway methods and are out of scope for this table.

#### Interactor naming

- **File**: `lib/domain/<context>/interactors/<entity>_<action>_interactor.rb` (e.g. `crop_create_interactor.rb`, `farm_detail_interactor.rb`).
- **Execution method**: **`call(input)`** only. `execute` and `perform` are forbidden. Jobs that wrap an interactor translate `perform` → `interactor.call`. **`output_port` is passed via constructor keyword argument.**
- **One user-facing use case ⇒ one top-level interactor**: HTML and API share the same orchestrator — see [R5](#r5-output-port-contract). No `*HtmlInteractor` / `*ApiInteractor` split. Sub-steps use [Input port injection](#composite-use-cases-and-input-port-injection), not a second top-level interactor from the controller.
- **Input port file**: `lib/domain/<context>/ports/<sub_step>_input_port.rb` (e.g. `plan_allocation_adjust_input_port.rb`). Sub-step Interactor implements it: `class PlanAllocationAdjustInteractor < PlanAllocationAdjustInputPort`.
- **Edge build helper**: `CompositionRoot.build_<sub_step>_interactor(output_port:, clock:)` — not a Factory class visible to orchestrators.
- **Interactor responsibilities**: Orchestrates validation and business logic. Fetches data via gateways; may call sibling sub-steps via **Input ports**; passes data to Policies for validation; extrinsic validation (uniqueness, resource limits) is the Interactor's responsibility.

#### Domain DTO naming

Domain DTOs encode **use-case semantics only** - what the use case takes in, what it produces, and how it fails. Display shape is **not** a domain concern.

**Validation boundary:** **Intrinsic validation** (pure, no I/O - e.g. `start_date < end_date`, `name.length <= 100`, regex) belongs in **Policies** under `lib/domain/<context>/policies/`. **Extrinsic validation** (needs existing data - e.g. uniqueness, resource limits) is performed by **Policies** (Interactors fetch data via Gateways and pass to Policies). **DB constraints** (UNIQUE INDEX, CHECK) are the final safety net against race conditions.

| Role | File | Class |
|---|---|---|
| Input to interactor | `lib/domain/<context>/dtos/<usecase>_input.rb` | `<Usecase>Input` |
| Success output | `lib/domain/<context>/dtos/<usecase>_output.rb` | `<Usecase>Output` |
| Modeled failure | `lib/domain/<context>/dtos/<usecase>_failure.rb` | `<Usecase>Failure` |
| Persisted read-only snapshot | `lib/domain/<context>/dtos/<name>_snapshot.rb` | `<Name>Snapshot` |

**Disallowed in `lib/domain/`**:
- `*_dto.rb` suffix - `Input` / `Output` / `Failure` / `Snapshot` already encode the role; the redundant `_dto` tail is forbidden in new code.
- `persisted_*` prefix - predates the `Snapshot` suffix; rename to `<Name>Snapshot`.
- `*_read_model.rb`, `*_payload_dto.rb` - these are presenter-side ViewModels in disguise. Move to `app/adapters/<context>/presenters/view_models/`.

### Rails Application Layer

The Rails application layer lives under `app/`.

- `**ActiveSupport::Concern`** - **Do not add** new concern modules under `app/controllers/concerns/`, `app/models/concerns/`, or elsewhere to share **domain-shaped or use-case** logic. Express reuse in `lib/domain` as **Plain Ruby**, wire it with **explicit injection** at the edge.
- `**app/controllers/api/v1/`** - JSON API; request mapper / Form → input DTO → interactors + API presenters. Flow: [API Layer](#api-layer), [Canonical use-case responsibility split](#canonical-use-case-responsibility-split).
- `**app/controllers/*_controller.rb`** - HTML controllers for legacy/admin-style flows; increasingly delegate to interactors + HTML presenters.
- `**app/models/`** - ActiveRecord; **DB-level constraints only** (UNIQUE INDEX, NOT NULL, CHECK). Business validations follow [R0](#r0-authorization-and-validation). Model validations are **safety net only**.
- `**app/services/`** - Orchestration and legacy services; **prefer** moving durable rules into `lib/domain/.../interactors` and `lib/domain/.../policies` (see roadmap).
- `**app/adapters/agrr/gateways/`** - HTTP/process integration with the **agrr** daemon (optimization, weather, progress, etc.). These are infrastructure adapters, not domain entities.

### External agrr integration

- Gateways under `app/adapters/agrr/gateways/` encapsulate the agrr CLI/daemon protocol.
- Tests: `test/adapters/agrr/`.

## Rules

This section defines the normative rules for new code. Positive rules are stated first; prohibited patterns (**❌**) show common violations. Where common community patterns, prevailing pragmatism, or existing project conventions conflict with the rules below, this file takes precedence. "Existing code already does this" or "tests pass" does not override a rule — treat such mismatches as debt to fix, not a template to copy. Refactors must not **relocate** a smell (e.g. push the same coupling to a fat controller) or **reintroduce** the same dependency shape under a different name.

### R0. Authorization and Validation

**Policies define and evaluate rules. Interactors orchestrate: they fetch data via Gateways, pass it to Policies, and act on the results. Gateways never make authorization or validation decisions.**

This rule is the single source of truth for authorization and validation responsibilities across all layers. Other sections reference `[R0](#r0-authorization-and-validation)` instead of restating this relationship.

### Domain Layer

**R1. Framework-free** — Plain Ruby only. No `Rails.*`, no `ActiveRecord`, no framework mixins. Shared behavior and use-case judgment belong under `lib/domain` as ordinary classes/modules (policies, interactors, value objects).

- ❌ `Rails.logger`, `Rails.env`, `Rails.application` etc. from domain code
- ❌ `ActiveRecord::`* types in domain flow — map persistence failures to `Domain::Shared::Exceptions::`* in adapters only
- ❌ ActiveRecord APIs on objects in interactors (`record.association.where`, `pluck`, `includes`); passing AR models inward through gateways — map to **DTOs/entities** at the use-case boundary
- ❌ `Date.current`, `Time.current`, `Time.zone`, `n.days`/`n.months`/`n.years` without injected [`ClockPort`](#port-file-naming) (`today` / `now`) or explicit date/time arguments
- ❌ `SomeAdapter.new` or `Adapters::...` inside `lib/domain` — construct at the edge (`lib/composition_root.rb`, controllers, jobs) and inject **interfaces** only
- ❌ `*Port.default`, `*Gateway.default` or other hidden globals — dependencies must be **constructor-injected** from the edge
- ❌ Hiding Rails/AR in a base interactor, mixin, or shared superclass
- ❌ Injecting only some ports while `Date.current`, I18n, or config stay implicit
- ❌ Raw SQL, Arel, or HTTP/SDK clients used inside `lib/domain` without going through a gateway/port
- ❌ Durable logic expressed **only** through `app/models` callbacks/validations without equivalent policy/interactor path and tests

**R2. Constructor injection** — All dependencies passed explicitly via constructor keyword arguments. No hidden globals, grab-bag context objects, or `proc`/callable arguments that perform I/O. Tests must exercise the same constructor contract as production.

- ❌ `Current`, generic `context`/`deps` hashes, `ApplicationRecord` as grab bag
- ❌ Over-mocking so unit tests never exercise real constructor arity and types; relying on integration tests alone while production wiring still uses hidden globals

**R3. Gateway boundary** — Gateways are narrow persistence/HTTP/process I/O only. See [Gateway Boundary](#gateway-boundary) for details.

- ❌ Authorization, validation, use-case branching, or multi-step orchestration in gateways
- ❌ Presenter-shaped composites assembled inside gateway — compose in Interactor or output-port DTO
- ❌ "Nominal interfaces" — gateways that return AR types, expose query chains, or are single monolithic adapters
- ✅ Identity-scoped reads (`find_by_user_id(user_id)` etc.) — gateway only filters by given identity; **authorization and validation follow [R0](#r0-authorization-and-validation)**. Method naming follows [Gateway method naming](#gateway-method-naming-the-five-verbs)

### Use Cases

**R4. Use-case ownership** — Interactors orchestrate validation (via Policies per [R0](#r0-authorization-and-validation)), business rules, gateway orchestration, and optional **sub-steps via Input ports** ([Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection)). One **user-facing** use case ⇒ one **top-level** interactor; HTML and API share it. `call(input)` is the only execution method. `output_port` passed via constructor keyword argument.

- ✅ Inject sibling sub-steps as **Input port** types; edge builds `Interactor` implementations via `CompositionRoot.build_*_interactor(output_port:)`
- ❌ Raw `params`, `redirect_to`, `render`, HTTP status codes, flash
- ❌ View-only shaping — logic for specific layout/field order belongs in presenters; do not bloat DTOs to "align HTML and JSON"
- ❌ `CompositionRoot.*`, `*InteractorFactory`, or `new` on sibling Interactors inside `lib/domain` or adapters — wiring stays at the application edge (controllers, jobs)
- ❌ Orchestrator depending on concrete sub-step Interactor class instead of Input port
- ❌ Delivery channel or screen shape in names (`*HtmlInteractor`, `*_html_success`, `*JsonBundle*`)
- ❌ `execute` or `perform` as execution method — use `call(input)` only
- ❌ Interactors that only reshuffle what a controller previously did (trivial interactors)

**R5. Output port contract** — Success and modeled failures go through `output_port.on_success` / `on_failure` with explicit DTOs. The interactor decides outcomes; the presenter shapes HTTP.

- **Top-level unit of work** — one controller/job action ⇒ **one** orchestrator `Interactor#call` = one user-facing use case. Same use case ⇒ same top-level interactor for HTML and API; format differences belong in **presenters only**.
- **Nested sub-steps** — sibling interactors invoked through **Input ports** inside that call are allowed; each sub-step build at the edge has its **own** `output_port` for that invocation. They do not count as a second user-facing use case.
- Multiple read concerns in **one** response (e.g. farm detail + weather) ⇒ one orchestrator calling multiple **gateways**, not multiple top-level controller calls.
- The **top-level** output port lists what **the user-facing use case produces**. Sub-step outcomes are consumed via sub-step `output_port` implementations (collector or Presenter) or mapped DTOs in the orchestrator — **no fetch/load in the presenter**.
- ❌ `on_failure` then `raise` for the controller to rescue (second HTTP path)
- ❌ Presenter or view re-validates or recomputes outcomes instead of consuming interactor output DTO

### Output Ports

**R6. Display-only** — Presenters implement output ports and shape HTTP/view only. No data loading, no business rules, no side effects.

- ❌ `CompositionRoot.*` calls to load data for the response
- ❌ `*Gateway.default` or gateways used for `find_model` — loaded data belongs in Interactor output, carried as DTOs/entities on the port; not via controller-defined lambdas
- ❌ Authorization outcomes, validation rules, or "can this happen?" decisions
- ❌ Side effects from `on_success`/`on_failure`: `perform_later`, job dispatchers, external services, cache writes, date/cache branching
- ❌ **Presenters**, **Forms**, **ViewModels**, or **host/bridge adapters** calling `Interactor#call` on any interactor (top-level or nested)
- ✅ **Orchestrator interactors** calling a sibling sub-step through an injected **Input port** whose implementation is built at the edge — see [Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection)
- ❌ **Controller** calling multiple **top-level** interactors when one orchestrator should own rollback/compensation — use Input port nesting instead
- ❌ Forms performing authorization, uniqueness checks, or cross-record validation
- ❌ ViewModels calling gateways, `find_model`, or any I/O
- ❌ Mappers branching on business rules

### Application Edge

**R7. Thin controllers** — Controllers use a **request mapper or Form** for `params` → input DTO, instantiate presenter + interactor + gateways, and `interactor.call(input_dto)`. See [Checklist](#checklist) and [Canonical use-case responsibility split](#canonical-use-case-responsibility-split).

- ❌ `rescue StandardError`, `rescue ActiveRecord::RecordNotFound`, or `rescue_from` as the **primary** mapper for anticipated domain outcomes — use output port instead
- ❌ Business behavior inside action methods, private helpers, `before_action`, or controller-only `app/services/` adapters
- ❌ Passing raw `params` or `ActionController::Parameters` into Interactors — map to `<Usecase>Input` at the controller edge first
- ❌ ActiveRecord/ActiveStorage reads/writes for the use case (`current_user.farms.where(...)`, `Model.find`, `Blob.create_and_upload!`)
- ❌ Third-party SDK/process clients, retry loops, JSON parsing as control flow, cross-record aggregation, authorization branches, conditional `*Job.perform_later`, `Rails.cache.fetch` whose result selects domain output
- ❌ New CRUD or integration endpoints that don't route through an interactor
- ❌ Coupled orchestration left in `app/services/` or `lib/` outside `lib/domain/<context>/` — renaming the folder does not change the layer
- ❌ Host/bridge adapters or `*InteractorFactory` classes that call `CompositionRoot.*` to run a use case — inject `CompositionRoot.build_*_interactor(...)` at the controller/job and pass the result as an **Input port** (see [Composite use cases and Input port injection](#composite-use-cases-and-input-port-injection))

### Refactor Hygiene

**R8. Complete refactors** — Moving code without fixing dependency direction and types is **relocation**, not completion. Convenience is not an exemption — skipping layering because it is faster, when it commits us to wholesale rework afterward, **is rejected**.

- ❌ Moving coupled logic into a fat controller or fat `app/services/` without DTOs, ports, and constructor injection
- ❌ Tests that green-wrap a different graph than production (global stubs, implicit time) — fix production wiring first, then tests
- ❌ `# TODO: move to domain`, feature flags, or `legacy_path`/`new_path` branches without a plan and deadline to collapse them
- ✅ Deliberate interim steps belong in the **same PR or adjacent commits** with repayment, or their **lifetime and replacement** must be spelled out in the PR / goal statement and tests bound to that behavior — see `.cursor/rules/no-convenience-tech-debt.mdc`

### View Templates

- ❌ Duplicating or inventing business rules in ERB/partials/helpers instead of `lib/domain/`

### Contract-first Documentation

**R9. Contract-first** — Behavior is defined by **`ARCHITECTURE.md`**, **port/DTO contracts in `lib/domain`**, and **tests that encode observable behavior**, not by "matching whatever the legacy stack does."

- ❌ Treating the Rails/HTML implementation snapshot alone as the source of truth without ports, DTOs, and tests

### R10. Implementation order and Definition of done

**Safe implementation sequence** — Define the output port contract first, then implement in this order:

1. **Interactor (+ tests)** — gateway-only data load; port arguments match the new contract
2. **Gateway impl.** — implement the adapter the Interactor depends on
3. **Presenter** — HTTP/view mapping only; remove `CompositionRoot` / `find_model` / gateway injection from presenters (including via callables)
4. **Controller** — `CompositionRoot` injection into the top-level interactor (gateways, Input ports from `build_*_interactor`, presenter) only; do not pass gateways into presenters
5. **Views** — if `@model` assumed AR, replace with **DTO attributes and helpers** in the **same PR or the commit immediately before/after** — do **not** bring AR back through the presenter for convenience

**Definition of done** — `app/adapters/<context>/presenters/**/*.rb` contains **no** `CompositionRoot` and **no** `find_model`. Each target use case has an **Interactor test** that fixes **types and required fields** reaching the port. **System/controller tests** (where needed) prove HTML/JSON behavior is unchanged.

### Naming and Placement

Naming and placement conventions are defined in [Naming and placement conventions](#naming-and-placement-conventions) under Backend.


## Frontend

### Layer Structure

**Intended dependency direction**

```mermaid
flowchart TB
  Components[components_pages] --> UseCase[usecase]
  UseCase --> DomainFE[domain]
  UseCase --> GatewayIF[gateway_tokens]
  Adapters[adapters] --> GatewayIF
  Adapters --> RailsAPI[Rails_JSON_API]
```



- `**domain/**` - Types and pure rules (framework-agnostic where possible).
- `**usecase/**` - Use cases, gateway interfaces (injection tokens), ports.
- `**adapters/**` - API gateway implementations, presenters that map DTOs to view state.
- `**components/**` - Standalone components, routes, templates.
- `**services/**` - Cross-cutting and feature-specific helpers (authentication, list refresh, master API clients, etc.). HTTP and environment-dependent implementations belong in `adapters/` (T-053: empty `infrastructure/` layer is not adopted).
- `**core/**` - Cross-cutting utilities including i18n loader, API base URL, browser region, cookie consent helpers, `ListRefreshBus`, etc.
- `**guards/**` - e.g. `authGuard`.
- `**routes/**` - Per-feature route definitions composed by `app.routes.ts` (T-054).

### i18n

`@ngx-translate` with `frontend/src/assets/i18n/ja.json` and `en.json`.

### Routing

Production uses `PathLocationStrategy` (`app.config.ts`). The CDN routes SPA fallbacks to `index.html` via URL map (`scripts/agrr-frontend-url-map-simple.yaml`).

## Resource Limits

- **Farm limit:** max 4 non-reference farms per user (`is_reference: false`).
- **Crop limit:** max 20 non-reference crops per user.
- **Reference data:** `is_reference: true` records do not count toward limits.

Enforced in **domain Policies**. ActiveRecord validations and DB constraints are **safety net only** (last line of defense against corrupted data).

## Testing

**Production path (R4)**: `test/contract/**` with `CONTRACT_RUNTIME=rust` and co-located `agrr-server` — [`scripts/run-rust-contract-tests.sh`](scripts/run-rust-contract-tests.sh). This is the API/WS behavioral gate after P7.

**Domain logic**: `cargo test` in `crates/agrr-domain` — [`.cursor/skills/test-common/scripts/run-test-rust-domain.sh`](.cursor/skills/test-common/scripts/run-test-rust-domain.sh).

**Rails shell (shrinking, P8)**: `run-test-rails.sh` runs remaining Ruby tests (models, migrations, dev controllers, contract harness setup via ActiveRecord). `test/domain/`, `test/adapters/`, `test/channels/`, `test/jobs/` are removed with `lib/domain` and API adapters.

**Rules**

- Use runner scripts, not raw `rails test` (protects the development database). See [`.cursor/skills/test-common/SKILL.md`](.cursor/skills/test-common/SKILL.md).
- Rust changes: [`scripts/p7-code-removal-gate.sh`](scripts/p7-code-removal-gate.sh) before merge when touching server/migrate.
- Angular: [`.cursor/skills/test-common/scripts/run-test-frontend.sh`](.cursor/skills/test-common/scripts/run-test-frontend.sh).
- Rails removal phases: [`docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md`](docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md).

## Additional Resources

### Agent Workflow

The **Rules** section is the **primary specification**. **Execution procedures** for editor assistance and violation reduction tasks (discovery, ARCHITECTURE gate, full test suite, cross-repository scan) are defined in the following references. Boundary deviations for convenience must align with `[.cursor/rules/no-convenience-tech-debt.mdc](.cursor/rules/no-convenience-tech-debt.mdc)`.


| Reference                                                                                                                                                                                                  | Role                                                                                                                     |
| -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `[.cursor/rules/agent-conventions.mdc](.cursor/rules/agent-conventions.mdc)`                                                                                                                               | Terminology (**post-implementation Clean Architecture checks**: parent must not skip gate / test-common, etc.), workflow **section numbers**, and user-facing labels |
| `[.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md](.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md)`                                                                   | Outer and inner loops (**section 0** through **section 6**). Same procedure for new code, modifications, and reductions.  |
| `[.cursor/rules/ca-violation-fix-architecture-gate.mdc](.cursor/rules/ca-violation-fix-architecture-gate.mdc)`                                                                                             | Defines the ARCHITECTURE.md gate for **section 4** (**1st pass**, **2nd pass**, cross-check against Rules, mandatory output). Same procedure and format for Rails-only or `frontend/`-only diffs. |
| `[.cursor/skills/clean-architecture-violation-fix-workflow/references/agent-operational-canonical.md](.cursor/skills/clean-architecture-violation-fix-workflow/references/agent-operational-canonical.md)` | Backlog synchronization (no skipping of full scan), production confirmation, and shell completion procedure consolidation. |
| `[.cursor/rules/rails-testing-workflow.mdc](.cursor/rules/rails-testing-workflow.mdc)`                                                                                                                     | **test-common**-based testing for backend/frontend changes (do not run `rails test` directly on local machine)            |

### Related Documentation

- [docs/README.md](docs/README.md) (supplementary docs index)
- [.cursor/rules/rails-testing-workflow.mdc](.cursor/rules/rails-testing-workflow.mdc) (testing workflow rules)
- [.cursor/skills/test-common/SKILL.md](.cursor/skills/test-common/SKILL.md) (test execution scripts)

