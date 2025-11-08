## public_plans 最適化完了後の「作業予定（スケジューリング）」戦略（実装なし）

### 要点（TL;DR）
- 作物の作業全体は `agrr schedule` で GDDベースに立案（入力: stage_requirements + tasks）。
- 施肥（基肥/追肥）は `agrr fertilize plan` で GDDベースに立案（application_gdd）し、tasksへ取り込み。
- 追肥が未定義なら基肥のみで対応。定義があれば `fertilize plan` を優先採用（パラメータで切替可）。

### 目的
\- public_plans（公開計画）の最適化完了後、別ジョブで作業予定（農業タスクの実行計画）を自動立案する。
\- agrr の既存コマンドを活用し、天候・作物ステージ要件・作業タスクを踏まえた現実的なスケジュールをJSONとして取得・保存する。

### 前提/制約
\- 実装は行わない（本ドキュメントは設計/戦略のみ）。
\- 既存の agrr 連携は `AgrrService` を介する（daemon稼働が前提）。
\- 事前に agrr daemon を起動（例: `lib/core/agrr daemon start`）。daemon 未稼働時は多くのサブコマンド（help含む）が失敗する。
\- 作業予定の保存先スキーマ・UI反映は別途（ここではインターフェース方針と入出力のみを定義）。

### agrr コマンド（参考）
\- weather: 気象データ取得
\- forecast: 予報取得
\- crop: 作物プロファイル取得
\- progress: 作物進捗の計算（今回は使用しない）
\- optimize period/allocate/adjust: 期間最適化/配置最適化/調整
\- schedule: 作業タスクのスケジュール生成（本戦略の中核）
\- pest-to-crop: 害虫プロファイル→作物関連

`AgrrService` メソッド対応（一部抜粋）:
\- weather(location:, start_date:, end_date:, days:, data_source:, json: true)
\- progress(crop_file:, start_date:, weather_file:, json: true) ※今回の戦略では使用しない
\- optimize_period(...), optimize_allocate(...), optimize_adjust(...)
\- schedule(crop_name:, variety:, stage_requirements:, agricultural_tasks:, output: nil, json: true)

### トリガー/フロー（高レベル）
1) 最適化完了イベントの検知
\- public_plans の「最適化完了」を示す状態更新、またはジョブ完了Webhook/コールバックをトリガーにする。

2) 別ジョブでスケジューリングを実行
\- 入力: public_plan_id, 計画期間, 対象圃場, 対象作物、最適化結果（配置/期間等）、使用天候データの参照
\- 出力: 作業予定JSON（後続でDB保存）

備考（トリガー/オーケストレーション方針）:
\- 既存のチェイン仕組みはラッパー/コントローラ側に実装されており、個別ジョブ内にチェイン制御は実装しない（現行ポリシー）。
\- public_plans の最適化後スケジューリングは、既存チェインを使わず単独ジョブとして起動する場合がある（要件・再試行単位の都合）。
\- 必要に応じて `ChainedJobRunnerJob`/`JobExecution` concern を用いた直列実行は選択可能だが、本スケジューリングは「単発起動→完結」を基本とする。

3) agrr に渡す入出力の整理
\- stage_requirements: 作物の段階要件（`Crop#to_agrr_requirement` など既存変換を活用）。
\- agricultural_tasks: 参照作業 or ユーザー作業を agrr フォーマットに変換（`AgriculturalTask#to_agrr_format`/`to_agrr_format_array`）。
\- crop_name/variety: public_plan の対象作物定義から取得。

4) agrr schedule の呼び出し
\- `AgrrService.schedule` を用い、タスク候補（tasks.json）と段階要件（stage_requirements.json）から実行順序/タイミングを算出。
\- progress は不要。スケジュールはGDDベースで、ステージ要件とタスク制約から直接導出する。

5) 結果の保存と冪等化
\- 同一 public_plan に対する再生成時は上書き/差分反映のポリシーを定義。
\- 参照データから複製するエンティティには `created_from` を活用（重複防止）。
\- `task_type`（基肥/追肥/潅水/農薬散布/その他）でフィルタや優先度付けを可能にする。

### 入力データの準備（agrr向け）
\- 作物要件: `Crop#to_agrr_requirement` で agrr 期待形式の JSON を用意。
\- 作業タスク: `AgriculturalTask.to_agrr_format_array(tasks)` で agrr 期待形式の配列を用意。
  \- 基肥/追肥が含まれていない場合は、下記の「基肥・追肥タスクの自動追加」で補完してから agrr に渡す。
\- ルール: 相互作用ルールが影響する場合は最適化時と同じ `interaction_rules_file` を参照。

### 実行シーケンス（論理）
1. public_plan_id から計画期間・対象圃場・作物構成・最適化結果を取得
2. 作物ごとに stage_requirements JSON を準備
3. 対象作物に紐づく作業タスクを agrr 形式に変換（必要に応じて基肥/追肥を補完）
4. `AgrrService.schedule` を呼出し、作業予定JSONを取得
5. 保存ポリシーに従いDBへ格納（冪等）
6. 監査ログ/メトリクス送出（件数、所要時間、スキップ理由等）

### エラーハンドリング/リトライ
\- agrr daemon 未起動: 早期に検知し保留ステータスで再試行。
\- 入力不足: 作物要件やタスク欠損時はスキップ記録して継続。
\- JSON不整合: `AgrrService.execute_command` でJSON抽出を維持し、必要に応じて警告扱いで継続。

### スケール/実行形態
\- 1 public_plan あたり1ジョブ。作物単位の分割も可（長時間回避/再試行容易化）。
\- ジョブキューは冪等なキーで多重起動を防止。

### セキュリティ/監査
\- 入力JSON（要件/タスク）はPIIを含まない想定だが、ユーザー所有・参照データの境界に注意。
\- 保存時に `created_from` を活用して重複を回避。

### 期待アウトカム
\- 計画期間内での作業予定（日時/依存関係/優先度）。
\- `task_type` による集計/表示（後続UI活用）。

### GDD（積算温度）ベースのスケジューリング方針
\- 中核方針: 作業タイミングは暦日ではなく GDD 到達（またはステージ内 GDD 進捗）を主指標に決定する。

GDDの出所（agrr側の計算）:
\- agrr `schedule --help` より、出力には `gdd_trigger`/`gdd_tolerance` が含まれ、GDDベースのスケジュールであることが明示。
\- 入力は `stage_requirements`（各ステージ: `temperature.base_temperature`, `thermal.required_gdd` を必須）と `agricultural_tasks`。
\- GDDの計算は agrr 側で行われ、こちらの入力は stage_requirements と tasks のみ（weather を schedule に直接渡す必要はない）。

入力要件:
\- `stage_requirements` の各ステージに `thermal.required_gdd` と `temperature.base_temperature` が必須。

算出の基本:
\- 日GDD: `max(0, ((tmax + tmin) / 2) - base_temperature)`（暫定。上限温度のクリップは温度要件の `max_temperature` で任意）
\- ステージ到達判定: ステージ開始からの累積GDDが `required_gdd` に到達した日。
\- タスクの実施ウィンドウ: ステージ境界（開始/終了）やステージ内の割合（例: 30%時点）を累積GDDで逆算して日付レンジに変換。

タスク割付の指針:
\- 基肥: 播種/定植直前のステージ境界（前ステージ終了=次ステージ開始直前）に配置。
\- 追肥: 生育中期（例: ステージ内GDDの40〜70%）に1〜2回配置。IF/作物種により回数を調整。
\- 病害虫・薬剤: リスク閾値（IF）とGDD進捗の両方を考慮してウィンドウを絞り込み。

IF連携:
\- `gdd_constraints`: [{stage, type: "cumulative|within_stage", op, value}] を許容（例: within_stage >= 0.4 && within_stage <= 0.7）。
\- weather_constraints と併用して、GDD到達後かつ降雨回避など複合条件で実施日確定。

一貫性/再現性:
\- `base_temperature` 未設定の場合は作物/ステージの温度要件から必須化（デフォルト値は使用しない）。

### データ保存スキーマ（新規テーブル案）
現状のメイン`schema.rb`には作業予定保存用テーブルは存在しません（`db/cable_schema.rb`に `task_schedules` はありますが別DB用途）。そのため、作業予定保存用の新規テーブルを用意します。

テーブル名案: `task_schedules`
\- 用途: agrr `schedule` 出力JSONを、計画・作物・ユーザーに紐づけて保存

カラム案（最小）:
\- `cultivation_plan_id: bigint`（必須, FK）対象計画
\- `crop_id: bigint`（任意, FK）作物単位で生成した場合に利用
\- `user_id: bigint`（必須, FK）所有ユーザー
\- `schedule_data: jsonb`（必須）agrr出力（前処理エビデンス含む）
\- `status: string`（任意, default: "active"）active/draft/archived
\- `version: string`（任意）生成ポリシー/IFルールの版管理
\- `created_from: bigint`（任意）参照元（公開計画テンプレ等）
\- `metadata: jsonb`（任意）condition_evidence/入力ハッシュ/実行時間など
\- `created_at/updated_at`

インデックス案:
\- `(cultivation_plan_id)`
\- `(user_id)`
\- `(crop_id)`
\- パフォーマンス要件に応じて `(user_id, cultivation_plan_id)` 複合

備考:
\- 複数作物を一括スケジュール場合は、`crop_id` NULLで計画粒度の1レコードに集約、作物別は配列で `schedule_data` に格納。

### IF条件（条件付きタスク/制約）の設計
\- 目的: タスクの実施可否・回数・タイミングを「条件（IF）」で制御し、天候・生育・資源の不確実性に対応。

対象となる条件（例）:
\- 天候: 累積降水量、直近降水予測、風速、気温（最低/最高/積算）
\- 生育: ステージ到達、経過日数、ステージ内日数
\- 資源/運用: 作業者工数の空き、機材使用可否、休日回避
\- 環境/病害虫: 病害虫発生閾値、リスク指数

表現方式（初期案）:
\- tasks.json 内に簡易条件フィールドを許容
  \- `when`: すべて満たすと有効（AND）
  \- `unless`: いずれか満たすと無効（OR）
  \- `weather_constraints`: [{metric, op, value, window}]
  \- `stage_constraints`: [{stage, op, value}]（例: stage == "vegetative"）
  \- `workload_constraints`: 工数上限、同時並行制限

評価タイミング/方法:
\- 前処理（ジョブ内）でIFを評価し、`tasks.json` を以下のいずれかで確定
  \- スキップ: 条件不成立のタスクを除外
  \- 窓シフト: 条件に合わせて実施ウィンドウを前後に調整
  \- 分割: 一つのタスクを複数回に分割（例: 追肥を2回に分ける）
  \- 追加: 条件成立時に派生タスクを追加（例: 乾燥時は潅水を追加）
\- agrr `schedule` は前処理済みの tasks.json を入力として最適順序・日程を算出（`progress` なし）。

コンフリクト解決（優先度）:
\- 1) 安全/規制 > 2) 生理/生育要件 > 3) 天候適合 > 4) 効率（移動/段取り）
\- 競合条件が同時成立する場合は優先度で裁定し、低優先のタスクをシフト/スキップ。

冪等・説明可能性:
\- IF判定の根拠（メトリクス、しきい値、対象期間）を `condition_evidence` として結果JSONに添付。
\- 同一入力（天候・期間・作物・設定）で結果が決定的になるよう、乱数は使用しない。

ジョブ入力フラグ（例）:
\- `enable_if_rules`: true/false（デフォルト: true）
\- `if_rules_source`: `inline`（tasks.json内）/`rules_file`（将来の外部定義）
\- `safety_first`: true/false（安全優先の重みを強化）

将来拡張:
\- `interaction_rules_file` との連携（optimize系と整合したIFポリシー）
\- 地域/作物品種ごとのテンプレIFセット

テスト観点（実装時）:
\- IFの真偽でスケジュールが期待通りに変化する（スキップ/追加/分割/シフト）。
\- 競合時の優先度裁定が一貫している。
\- `condition_evidence` により意思決定が追跡可能。

### 基肥・追肥タスクの自動追加（補完）
\- 目的: ユーザー/参照タスク集合に基肥（basal_fertilization）や追肥（topdress_fertilization）が欠落している場合でも、最低限の施肥作業をスケジュールに反映。
\- 入力: 対象作物の `task_type` 分類済みタスク集合、作物段階要件（`stage_requirements`）、（あれば）必要施肥量/時期のヒント。
\- 出力: 既存タスク配列へ基肥/追肥タスクを追記した agrr 期待形式配列。

補完ポリシー（初期案）:
\- 基肥: 定植/播種の直前ウィンドウに1回挿入（`task_type: basal_fertilization`）。
\- 追肥: 生育中期以降、ステージ進行に応じて1〜2回挿入（`task_type: topdress_fertilization`）。
\- 制約: 天候依存（雨天回避など）・作業時間・前後依存を既存タスクと同等に付与。
\- 冪等: 既に同等タスクが存在する場合は重複追加しない（`name`/`task_type`/ウィンドウ近接のしきい値で判定）。

優先方針（基肥/追肥の定義状況による挙動）:
\- 基肥のみ定義あり（追肥なし）: 追肥位置を計算する根拠がないため、基肥のみで対応（追加追肥は行わない）。
\- 基肥・追肥の両方が定義あり: 追肥の具体的なタイミングは `agrr fertilize plan` の `application_gdd` を優先採用し、tasks.json に変換して反映（必要に応じて `gdd_constraints` を付与）。

優先度の切替（ジョブパラメータ）:
\- `fertilize_strategy`: `tasks_only` | `fertilize_merge` | `fertilize_preferred`（既定: `fertilize_preferred`）
  \- `tasks_only`: tasks定義のみで補完（fertilize planは使わない）
  \- `fertilize_merge`: tasksの追肥定義があれば維持、未定義分のみ fertilize plan の結果を補完
  \- `fertilize_preferred`: 追肥タイミングは fertilize plan を優先し、tasks側の追肥は上書きまたは整合調整

インターフェース（ジョブ入力フラグ例）:
\- `enable_auto_basal_topdress`: true/false（デフォルト: true）。
\- `topdress_count_hint`: 0/1/2（未指定時は作物ステージから推定）。

検証:
\- 追記後の tasks.json が agrr バリデーションを満たすこと（必須キー・依存関係）。
\- 参照データ由来のタスク追加時は `created_from` を活用して重複を避ける設計（保存層）。

補足（fertilize コマンドとの関係）:
\- `agrr fertilize` は肥料情報の検索（LLM）であり、GDDを直接扱うオプションはヘルプに記載なし。
\- 施肥のタイミング（基肥/追肥）は、本スケジュールではタスク＋`gdd_constraints`でGDD連動させる。追肥については `fertilize plan --crop-file ... [--use-harvest-start] --json` の `application_gdd` を tasks に取り込む構成を推奨。

### 動作確認のためのコマンド例（参考・実装外）
\- agrr daemon 稼働前提での生コマンド例（リポジトリ同梱のバイナリを想定）

```bash
# 事前: daemon起動
lib/core/agrr daemon start

# 天候取得（JSON）
lib/core/agrr weather --location 35.68,139.77 --start-date 2025-03-01 --end-date 2025-04-30 --json

# 作業スケジュール生成（stage_requirements.json, tasks.json を用意）
lib/core/agrr schedule \
  --crop-name "Tomato" \
  --variety "General" \
  --stage-requirements stage_requirements.json \
  --agricultural-tasks tasks.json \
  --json
```

Rails 経由（daemon/ソケット利用）の呼び出し例（概念）:
```ruby
# AgrrService.schedule(crop_name:, variety:, stage_requirements:, agricultural_tasks:, output: nil, json: true)
```

### ロールアウト方針（段階）
1. 入力整備（to_agrr_requirement / to_agrr_format_array の点検とテスト）
2. スケジューリングジョブの雛形（I/Oのみ、保存はドライラン）
3. 保存ポリシー（冪等/上書き/差分）の合意
4. メトリクス/ログの整備（計画別の生成率/失敗率）
5. UI連携（一覧/詳細の表示、`task_type` フィルタ）

### テスト方針（実装時の指針）
\- agrr連携は外部依存のためdaemon有無を切替できる統合テストと、I/Oの単体テストを分離。
\- スケジュール生成結果の構造妥当性（必須キー/時系列整合）。
\- 冪等性（同一入力で多重実行しても一貫した結果保存）。



### 未解決/検討事項（要合意）
\- schedule 入力スキーマの確定範囲
  \- 必須: name/time_per_sqm/weather_dependency/依存関係/作業ウィンドウの表現粒度
  \- 任意: when/unless/weather_constraints/stage_constraints/workload_constraints の正式キー名
\- IF評価の責務境界
  \- すべて前処理で確定 vs schedule 側で一部解釈（将来）
\- （削除）天候データの同一性保証
\- 複数圃場・複数作物の同時スケジュール
  \- 作物単位で分割実行か、まとめて投入か（実行時間/再試行単位）
\- リソース制約（作業者・機材）のモデル化
  \- 同時並行の上限/所要時間計算/移動ロスの扱い
\- 休日・時間帯制約
  \- 営業日カレンダ/作業時間帯の入力方法（週パターン/例外日）
\- 基肥/追肥の自動補完の詳細
  \- 追肥回数のヒューリスティク/ステージ対応、窓幅、重複判定しきい値
\- 参照/ユーザー混在タスクの保存設計
  \- `created_from` の付与対象と粒度（タスク/関連）
\- ルールのバージョニング
  \- IF/補完ポリシーのバージョン管理と再生成の再現性
\- エラー時のポリシー
  \- タスク単位スキップ/ジョブ失敗/部分コミットの基準とリトライ回数
\- ログ/監査
  \- `condition_evidence` の最小必須項目と保存期間
\- Dry-run と比較
  \- 本保存前に差分プレビューするI/F（UI/JSON保存）
\- セキュリティ
  \- ジョブ実行権限、ユーザーデータ境界の検証
\- パフォーマンスとバッチング
  \- 大規模public_planでの分割戦略、キュー設定、タイムアウト

