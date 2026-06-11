# 私的計画（/plans）新規作成: 空計画作成フローへの刷新 実装計画

作成日: 2026-06-11（v2 全面改訂: select-crop ステップ廃止・空計画作成方針）
状態: 提案（未実装）

## 0. 方針（v2 での変更点）

v1 は「既存 2 ステップウィザード（農場選択 → 作物選択）への導線復旧」だったが、方針を変更する:

> **private plan は select-crop せずに「空の計画」を作る。作物・圃場はマスタを利用する形にする。**

- 作成時に決めるのは **農場（+ 任意の計画名）だけ**。作成と同時にワークベンチ（計画詳細）へ直行する。
- **圃場**: 農場に登録済みの**マスタ圃場をコピー**して計画の圃場行にする（現状の「総面積×作物数から圃場を合成する `FieldsAllocation`」を private では使わない）。
- **作物**: ワークベンチの既存「作物を追加」（`add_crop`）で**作物マスタから後付け**する。workbench payload は既に `available_crops`（マスタ作物一覧）を含んでおり、この部分は**実装済み資産をそのまま使う**。

## 1. 症状と調査結果

**症状**: 計画の新規作成ができない。

**直接原因（導線欠落）**: `/plans/new` への `routerLink` が select-crop 画面の「戻る」のみ。
計画一覧（`plan-list.component.ts`）に作成ボタンがなく、ナビバーの「作付け計画を作成」
（`nav.new_plan`）は公開フロー `/public-plans/new` 固定。URL 直打ち以外で到達不能。
`ja.json` には `plans.index.create_new` 等のキーが定義済みなのに未使用で、
Rails ERB → Angular SPA 移行時に導線と空状態 UI が落ちたもの。

**空計画化の成立条件（バックエンド調査）**: 現状のままでは空計画は作れない。障害は 4 点。

| # | 障害 | 根拠 |
|---|---|---|
| 1 | `crop_ids` 空は 422 拒否（`plans.errors.select_crop`） | `private_plan_initialize_from_selection_interactor.rs:106` |
| 2 | 計画の圃場はマスタ圃場ではなく `FieldsAllocation` による合成（総面積を作物数で配分） | `cultivation_plan_initialize_interactor.rs:233-257` |
| 3 | `total_area <= 0` は作成失敗 → 圃場未登録の農場では計画を作れない | `cultivation_plan_initialize_interactor.rs:132` |
| 4 | 作成直後にフル最適化チェーン（bootstrap → fetch_weather → weather_prediction → optimization → plan_finalize）を enqueue。作物 0 件だと optimization が「field_cultivations 0 件」でエラー、finalize が plan を **failed** にする | `plans.rs:202` → `optimization_job_chain.rs`, `optimization_chain_run.rs:415,446-463` |

**利用できる既存資産**（この方針が低コストで成立する理由）:

- `POST /api/v1/plans/cultivation_plans/{id}/add_crop`（`AddCropInteractor`: マスタ作物解決 → 配置候補 → adjust → sync）実装済み。気象予測未完了時は `PredictionIncomplete` をモデル化済み
- workbench payload（`GET /api/v1/plans/cultivation_plans/{id}/data`）に `available_crops`（マスタ作物行）が含まれ、ガント UI（`gantt-chart.component.ts` / `gantt-plan-coordinator.service.ts`）に add_crop / add_field / remove_field / adjust の操作系が実装済み
- 計画詳細画面はステータスでゲートしておらず、空計画でもワークベンチ表示自体は可能
- マスタ圃場のコピーに必要な口は既存: `FieldGateway::farm_fields_list(farm_id)`、`FieldEntity { name, area, daily_fixed_cost, .. }`（`crates/agrr-domain/src/field/`）。create エンドポイントには `FieldSqliteGateway` が注入済み
- 進捗配信: `PlansOptimizationChannel`（cable）と購読ユースケース `subscribe-plan-optimization` が実装済み

**維持する制約**:

- 1 農場 1 計画（`plan_already_exists_annual`、`find_existing(farm_id, user_id)`）
- Farm 4 件 / Crop 20 件のリソース制限（Domain Policy）
- 圃場上限（`cultivation_plan_field_policy::max_fields_reached`）

## 2. 新フロー（UX）

```
計画一覧 /plans
┌──────────────────────────────────────────────┐
│ 計画一覧                  [+ 新しい計画を作成] │ ← plans.index.create_new
│ （0件時: 空状態メッセージ + 同 CTA）           │
└──────────────────────────────────────────────┘
   ↓
農場選択 /plans/new （1 画面で完結。select-crop は廃止）
┌──────────────────────────────────────────────┐
│ 📅 農場を選択してください                      │
│  農場:   [▼ 第一農場（圃場2・320㎡）]          │
│  計画名: [____________]（任意・既定は農場名）   │
│                                              │
│  ⚠ 圃場が未登録の農場は選択不可。              │
│    「圃場を登録する」→ /farms/:id             │
│                        [キャンセル] [作成]    │
└──────────────────────────────────────────────┘
   ↓ POST /api/v1/plans { plan: { farm_id, plan_name } } → 201 { id }
ワークベンチ /plans/:id に直行
┌──────────────────────────────────────────────┐
│ ☁ 気象データを準備中…（完了で消える）          │ ← cable 購読（Phase 4）
│ ガント: マスタ圃場コピーの圃場行のみ・作物なし   │
│ [作物を追加] → available_crops（マスタ）から    │
│   選択 → 候補計算 → 配置（既存 add_crop）       │
└──────────────────────────────────────────────┘
```

UX 上の根拠:

- 「農場を選んで作る」というメンタルモデルに一致し、作成までのクリック数最小（一覧 → 農場選択 → 作成）。
- 作物選択を作成時の必須関門にしない。計画は「箱」であり、中身（作物配置)は
  ワークベンチで対話的に組み立てる — 既存の add_crop/adjust 操作系と一貫する。
- 圃場がマスタ実物のコピーになることで、ガントの圃場行が現実の圃場名・面積と一致する
  （現状の「1」「2」という合成圃場名より分かりやすい）。

## 3. バックエンド設計（Rust）

### 3.1 作成 API 入力の変更

`POST /api/v1/plans` の body を `{ plan: { farm_id, plan_name? } }` にする。
`crop_ids` は**受理しない**（送られても無視。フィールド自体を `CreatePlanParams` から削除）。
互換のための残置はしない（project-necessary-code-only。クライアントは同リポジトリの SPA のみ）。

### 3.2 ドメイン: 空計画初期化

`PrivatePlanInitializeFromSelectionInteractor` を「農場のみから初期化」に改修
（実態が selection でなくなるため `PrivatePlanInitializeInteractor` 等へのリネームを推奨）:

- 削除: `crop_ids` 空ガード（障害 1）、`resolve_private_plan_crops`、`PrivatePlanCropListGateway` 依存
- 維持: 農場所有チェック（`farm_policy::owned_visible`）、既存計画チェック、計画名既定値（農場名）、planning 期間（年初〜翌年末）
- 圃場シード（障害 2・3）: `FieldGateway::farm_fields_list(farm_id)` でマスタ圃場を取得し、
  `name / area / daily_fixed_cost` を計画圃場（`CultivationPlanFieldMutationGateway::create_field`）へコピー。
  `area` が nil/0 の圃場はスキップ（`invalid_field_area` ポリシー準拠）。
  有効圃場が 0 件なら **422**（メッセージ: 圃場登録への誘導文言。i18n 新設 `plans.errors.no_fields_in_farm`）。
  `total_area` はコピーした圃場面積の合計。
- `CultivationPlanInitializeInteractor`（public 共用）は**変更しない**。private の圃場シードは
  上記インタラクタ側で行い、`PrivatePlanInitializeCallablePort` 実装（server 側 initializer）の
  圃場合成経路を通らない形にする（public の `FieldsAllocation` 経路はそのまま）。
  ※分割の具体形は実装時に ARCHITECTURE.md ゲート（禁止 1–39）で照合する。

### 3.3 作成後ジョブ: 気象準備チェーン（障害 4）

フルチェーンの代わりに **weather-prep チェーン**を enqueue する:

```
bootstrap → fetch_weather_data → weather_prediction → （終了。optimization / plan_finalize なし）
```

- 既存 step 関数（`optimization_chain_run.rs`）を再利用し、`optimization_job_chain.rs` に
  `enqueue_private_plan_weather_prep_chain` を追加。
- 完了時に `PlansOptimizationChannel` へ完了イベントを broadcast（ワークベンチのバナー消去用）。
- これにより add_crop の前提（気象予測完了）が作成直後のバックグラウンドで満たされる。
  準備完了前に add_crop した場合は既存の `PredictionIncomplete` 応答がそのまま機能する。
- 計画ステータスは **`pending` のまま**とする。`completed` への遷移ポリシー
  （field_cultivations 完了が条件）は変更しない。一覧 UI は現状ステータス非表示のため影響なし。
  ステータス語彙の再設計（例: 「作物未配置」）は別タスク。

### 3.4 契約テスト

R4 契約（`scripts/run-rust-contract-tests.sh`）の `POST /api/v1/plans` ケースを更新:
作物なし作成の 201、圃場なし農場の 422、既存計画ありの 422、crop_ids 送信時に無視されること。

## 4. フロントエンド設計（Angular）

### 4.1 導線（v1 設計を継承）

1. **計画一覧**: ヘッダーに「+ 新しい計画を作成」（`plans.index.create_new`、→ `/plans/new`）+
   0 件時の空状態（`no_plans` / `no_plans_hint` + CTA、副次リンク `try_public_plans`）
2. **ナビバー**: `nav.new_plan` をログイン時 `/plans/new`、未ログイン時 `/public-plans/new` に出し分け

### 4.2 農場選択画面 `/plans/new` の拡張

- 計画名入力欄を追加（任意。placeholder は `plans.new.plan_name_placeholder`、既定が農場名である旨は
  `plans.new.suggested_plan_name_hint` — いずれも既存キー）
- 送信を「次へ」でなく**「作成」**にし、`CreatePrivatePlanUseCase` を直接実行
  （入力 DTO から `cropIds` を削除: `{ farmId, planName? }`）
- 成功時は `/plans/:id`（ワークベンチ）へ遷移（`create-private-plan.presenter.ts` の遷移先を
  `optimizing` から変更）
- 農場 0 件: 空状態（`plans.new.no_farms` / `no_farms_hint` / `create_farm_link` → `/farms/new`）
- 圃場 0 件の農場: 選択肢に「（圃場未登録）」を付して disabled、または選択時に警告 +
  `/farms/:id` への CTA。farms 取得は既存 `/api/v1/masters/farms` の fields を流用
  （`fetchFarm` と同様に合計面積を出せる）。サーバー側 422 は最終防衛線

### 4.3 select-crop の削除

- 削除: `plan-select-crop.component.*`、ルート `plans/select-crop`、
  `load-private-plan-select-crop-context.*`（usecase / presenter / gateway メソッド `fetchFarm`・`fetchCrops` のうち不要分）、
  関連 i18n キー（`plans.select_crop.*` の未使用化分）
- 残す: `plans/:id/optimizing` ルートと購読ユースケース（公開フロー由来の遷移・再訪で使用中のため現状維持。
  不要と確認できたら別タスクで整理）

### 4.4 ワークベンチ（Phase 4・任意だが推奨）

- 気象準備中バナー: `subscribe-plan-optimization` を計画詳細でも購読し、weather-prep 完了イベントで消す。
  v1 リリースは省略可（準備完了前の add_crop は既存エラーメッセージで案内される）
- 圃場の後付け追加もマスタ圃場選択式にする（現状 add_field は自由入力名+面積）。
  「圃場はマスタを利用」の完全化はこの段で行う

## 5. 実装フェーズ（TDD・コミット単位）

各フェーズで「個別ファイル指定 GREEN → 全体実行」、ARCHITECTURE.md ゲート照合を行う。

- **Phase 1（導線・即効）**: 一覧の作成ボタン + 空状態、ナビバー出し分け、農場 0 件空状態。
  既存フローのまま入れられるため最初に出す。テスト: `plan-list` / `navbar` / `plan-new` の spec
- **Phase 2（バックエンド）**: ドメイン改修（空計画 + マスタ圃場コピー）→ server 配線
  （`plans.rs` create、weather-prep チェーン）→ R4 契約更新。
  テスト: `run-test-rust-domain.sh`（interactor 単体）→ `run-rust-contract-tests.sh`
- **Phase 3（フロント切替）**: `/plans/new` を作成画面化、presenter 遷移先変更、select-crop 削除、
  i18n 追加（`plans.errors.no_fields_in_farm` ja/en）。テスト: frontend 全体
- **Phase 4（ワークベンチ強化・後続）**: 気象準備バナー、add_field のマスタ圃場選択式化

デプロイ順序: Phase 2（API が crop なし body を受けられる状態）→ Phase 3 の順なら
旧フロントとの不整合ウィンドウなし（`crop_ids` は受信しても無視されるだけ）。

## 6. 受け入れ条件

1. ログインユーザーが一覧から **2 クリック + 農場選択**で計画を作成できる
2. 作成された計画の圃場行が、選択農場のマスタ圃場（名前・面積）と一致する
3. 作成直後にワークベンチが開き、「作物を追加」でマスタ作物から配置できる
   （気象準備完了前は準備中の旨が案内され、failed にはならない）
4. 圃場未登録の農場では作成できず、圃場登録への導線が示される
5. 農場 0 件・計画 0 件の各空状態で行き止まりにならない
6. 既存計画のある農場では従来どおり 422（1 農場 1 計画）
7. domain（cargo）・R4 契約・frontend の全テスト GREEN

## 7. 論点・残課題

- **計画圃場はマスタの「作成時スナップショット」**とする（マスタ圃場を後から変更しても既存計画に
  追従しない）。追従が必要なら別設計（参照化）であり本計画のスコープ外
- `plans/:id/optimizing` 画面・チャネルの私的フローでの今後の役割整理（公開フロー側と共用のため温存）
- 計画ステータス語彙の見直し（空計画が `pending` のままで良いか）— 一覧にステータス表示を入れる際に再検討
- 一覧カードの情報量強化（農場名・圃場数・作物数。i18n `plans.index.plan_card.*` 定義済み、一覧 API 拡張が必要）
