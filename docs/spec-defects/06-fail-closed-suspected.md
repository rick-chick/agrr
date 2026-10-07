# 06. fail-closed 違反の疑い（8 項目）と同種箇所: 判定と対応計画（厳格適用）

**種別:** 仕様不具合の対応計画（ドキュメント）。本書はコードを変更しない。
**版:** 第 3 版。§0 の決定「厳格」を反映した。第 1 版の判定（違反確定 / 仕様上許容 / 要判断）は §2.1 の「旧判定」列に残し、確定判定へ置き換えた。第 3 版は既存の判定を変えず、次の 4 点を更新した。(1) README の決定事項（第 1〜3 回）と、05・07・08・10 の最新版に合わせた依存と本文の形（§0 末尾、§3.3、§3.9、§7.1 の Q1・Q2、§9）。(2) master の #1337〜#1344 が特性化テストで固定した現状挙動の一覧（§2.5）と、それに伴う TDD 計画の更新（§5、§6、§8）。(3) 行番号の再確認（次の「行番号の再確認」）。(4) 05 が本書へ送ったが本書で未割当だった箇所と、01 R9 が挙げた箇所の受け皿（§2.3 の H11・H12、§7.2 R12）。
**対象:** `crates/agrr-server/src/entry_schedule.rs`、`crates/agrr-domain/src/field_cultivation/interactors/field_cultivation_climate_data_interactor.rs`、`crates/agrr-server/src/optimization_chain_phase.rs`、`crates/agrr-domain/src/cultivation_plan/{calculators/fields_allocation.rs, interactors/cultivation_plan_initialize_interactor.rs, interactors/entry_schedule/window_service.rs}`、`crates/agrr-server/src/weather_reschedule_proposals.rs`。第 2 版で追加した対象は §2.2 と §2.3 に file:line 付きで示す。

根拠は 2026-09-29 時点（第 1・2 版）と 2026-10-07 時点（第 3 版。`master` = `3de664648`、#1344）で実際に読んだファイル・実行した `rg` / `ls` / `sed` / `git diff` と、fixture JSON の集計（`python3`）のみ。読んでいない・実行していないものは「未確認」と明記する。テストは実行していない（本書は調査と計画のみ）。§2.5 の「固定している挙動」は、テストのソースを読んで得たもので、`cargo test` の結果ではない。

**行番号の再確認（第 3 版）:** 第 2 版の基準（`cdfd21ac6` 以降）から `3de664648` までに変わった `crates/` の非テスト行は 3 か所だけで、いずれもファイル末尾への追記か、テストモジュール内の挿入である（`git diff cdfd21ac6 HEAD --stat -- crates` と `git diff` で確認）。(a) `field_cultivation_climate_data_interactor.rs` の末尾（`:641-648`）に、`interactors_field_cultivation_climate_data_interactor_test.rs` を取り込む `#[cfg(test)]` ブロックが加わった。(b) `fields_allocation.rs` の末尾（`:79-87`）に、`calculators_fields_allocation_test.rs` を取り込むブロックが加わった。(c) `optimization_chain_phase.rs` のテストモジュールに、`:299-313` のテスト 1 件が挿入された。本書が引用する非テスト行は、これらより前にあるため不変である。本書が file:line で引用した 262 件を、実ファイルの該当行と突き合わせた。python3 で引用を抽出し、該当行の先頭を読み出して、引用の説明と構文が一致するかを確認した。ファイル名が複数のファイルに該当する引用は、実体を指定して確認した。ずれていたものは本文で訂正した。主な訂正は次のとおり。`optimization_chain_phase.rs` の `run_guarded_optimization_step_skips_when_plan_not_optimizing` は `:300-321` から `:315-337`。`has_transplant_stage` のテストは `:62-76` から `:62-78`。`entry_schedule.rs` のテストモジュールは `:644-` から `:645-`。`returns_failure_when_total_area_is_not_positive` の `#[test]` は `:171` から `:173`。`entry_schedule.rs` の `CropWrap` は `:98-124` から `:97-124`、`AgrrCropBuilder` は `:131-142` から `:127-142`。テストファイルの行番号は #1337〜#1344 で大きくずれたため、§2.5 は関数名と現在の行番号を併記した。

---

## 0. 決定事項

**決定:** fail-closed を**厳格に適用**する。第 1 版で「仕様上許容」「要判断」とした項目を含め、成功を装う代替値・既定値・握りつぶしを許容しない。

**出典と解釈:** これはユーザー指示「厳格」（`docs/spec-defects/README.md` の「決定事項」表「厳格」行）からの**解釈**であり、ユーザーが個別の項目ごとに指示した内容ではない。誤りがあればこの節を差し替える。

**厳格適用の具体（解釈の展開）:**

1. 成功を装う代替値・既定値・別アルゴリズムを残さない。本番への到達性と重大度は、「修正する / 削除する」の判定には影響させない（実装順序にだけ使う）。
2. 「許容」に残すのは次の 2 つに限る。理由をコードで確認できたものだけを記録する。
   - 入力省略に対する仕様上の正常な既定値（§4.1）。既定値で埋めても、後段の検証が明示的に拒否する場合を含む。例: `add_field_interactor.rs:72` は `field_area.unwrap_or(0.0)` の後、`invalid_field_area` で `on_invalid_field_params` を返す（`add_field_interactor.rs:73-75`）。
   - 業務上意味のある「行なし」「`Ok(None)`」。ただし DB エラーと区別し、停止や `None` は観測可能（ログまたは明示結果）にする。無言の停止は許容に含めない。
3. 修正後の形は、明示エラー（`on_failure` / 4xx・5xx とエラーコード）、`eligible: false` と理由、`501` のいずれか。握りつぶしを「ログだけ残して成功形を返す」に置き換えることは修正と認めない。
4. 本番から到達しないコードは、修正より**削除**を第一選択にする（`.cursor/rules/project-necessary-code-only.mdc`）。
5. ユーザー確認に残すのは、外部から見える契約（HTTP ステータス・エラー形）、製品仕様、テスト実行経路、可用性とのトレードオフに限る。§7.1 に理由付きで 5 件を残した（第 3 版で Q5 を追加）。

**第 1 版からの主な変更:**

- 許容・要判断だった項目 3・4 を確定した。項目 3 は削除（明示失敗）、項目 4 は「許容」部分の実態を再確認して修正へ。
- 到達不能の項目 5・6・7 を「潜在違反として修正または削除」に確定した。項目 6 は、本番の呼び出し元が常に `"public"` を渡すことを新たに確認し、`with_private_planning` ごと削除へ。
- 依頼外の A〜G を本課題の範囲に含めた。05 が扱う A・B は本書で二重に直さない（§2.2）。
- 同型の握りつぶし H 系と、失敗し得ないシリアライズの握りつぶしのクラス S を追加した（§2.3）。第 3 版で H11・H12 を追加した。
- 機械検出は、厳格方針の下で再評価し、`agrr-domain` に限定した 1 ルールを推奨に更新した（§4.2）。

**第 3 版: 他課題の決定との整合（本書の判定は変えない）:**

README の決定事項（第 1〜3 回）のうち本書に関わるものと、05・07・08・10 の最新版との整合を、次のとおり固定する。読んだ版は、05 が改訂 2、07・08・10 と 01・02・03 が 2026-10-07 時点の作業ツリー（未コミットを含む）である。各決定は「文脈からの解釈」を含むため、解釈が差し替わったら該当行を直す。

| 決定・他課題の記述 | 本書への影響 | 反映先 |
| ------------------ | ------------ | ------ |
| 第 2 回「errors」・第 3 回「削除」（07 §0.2、§0.3、§3.3 の C1〜C9、§3.6） | 本書が新設・変更する失敗応答の本文は、`errors`（非空の文字列配列）を必須とし、機械可読コードは任意の `error_code` に置く（例: `{"errors": ["メッセージ"], "error_code": "コード"}`）。`error`（単数）と `message` は失敗の主メッセージにしない。`success: false` などの付加情報は許容される（C8）。実装は `api_error.rs` のヘルパー経由で、新規の失敗は `Legacy::None`（07 §3.6）。本書が触る既存の `error` / `message` 箇所（`entry_schedule.rs` の `error` 7 箇所、`field_cultivation_climate.rs` の `message` 5 箇所、`account.rs` の `error` など）は、07 の S1 で旧キーが併記され S2 で撤去される（区分 A / B。07 §2.7 の #9・#15・#18）ため、本書の失敗応答の変更は 07 の手順 2（`api_error.rs` の導入）の後に行う（07 §10 の 05・06 行）。`weather_reschedule_proposals.rs` は既に `errors`（区分 C。07 §2.7 の #14）で、本文の変更は無い | §3.3、§3.8、§3.9（D・H1・S3）、§6、§7.1 の Q1・Q2 |
| 05 改訂 2（05 §3.A-6、§5.A） | 失敗通知は出力ポートの `on_failure(FieldCultivationClimateFailure { reason, message })` 1 つで、種別は `FieldCultivationClimateFailureReason`。第 2 版が参照した `on_progress_unavailable` は 05 から消えた。本書の「予測未生成」「予測ペイロード欠落」は、同じ enum の種別として追加する。HTTP は `reason` の網羅的な `match` で決め、`status_for_message` の文字列推定を使わない。作業記録側は `on_climate_snapshot_unavailable` と `WorkRecordClimateSnapshotUnavailableError`（05 §5.A の 9） | §2.2、§3.3、§7.1 の Q2 |
| 第 2 回「閲覧も許さない」・第 3 回「縮小」（10 §0。Plan 系は所有者のみ、Farm / Crop の編集も所有者のみ） | 本書の判定は変わらない。10 は `climate_data` の認可を適合とし変更しない（10 §0 の D2 の確定、§2.2 の表）。10 の縮小は次の 3 点で本書に触れる。(a) `cable.rs:402-407` の `member_organization_ids(..).unwrap_or_default()` を不要にして除去する（10 §8.1、T7-13）ため、§2.4 の未精査候補から外れる。(b) `work_record_{create,update}_interactor.rs` ほかのコンストラクタから `scope_gateway` を外す（10 §4.1）ため、§2.5 の H9 のテスト（`&EmptyScopeGateway` を渡す 2 件）の呼び出しも更新対象になる。(c) `weather_reschedule_proposals.rs:125,200` の scope gateway の生成を除く（10 §2.9.3）ため、項目 8 の行番号が実装時にずれる | §2.4、§2.5、§6 |
| 第 3 回「移行する」・第 2 回「削除」（03 の V27 と `apply_crop_setup` の削除） | 03 の V27 を含む作業ツリーから `run-production-data-migrate.sh` を実行すると V27 も適用される（03 §5.4.4 の 0.4）。本書の事前確認のうち、参照作物の `cultivation_method` の補修は同じ経路を使うため、V27 の窓と分ける（§6 のステップ 0）。読み取り専用 SQL は同じ復元コピーで続けて行ってよい（03 §10 の 06 行） | §6 |
| 第 1 回「Cloudflare」（02 の Turnstile） | 検証器は `contact_message_recaptcha.rs` から `contact_message_turnstile.rs` へ置き換わる（02 §5 の edge 行）。secret 未設定は 503 で fail-closed のまま（02 D-3） | §2.4、§9 |
| 第 3 回「共有」（01） | 本書と独立 | – |

---

## 1. 概要

### 1.1 目的と規範

`unwrap_or*` / `.ok()` で失敗を握りつぶし、代替値で成功に見せる箇所について、対応方針・TDD 計画・実装順序を定める。第 1 版の 8 項目に、同種の箇所を追加した。

適用する規範（すべて全文を読んだ）:

- `ARCHITECTURE.md:69-73` と `:106-111`: ドメイン判定・ビジネスロジックは、主経路失敗時に別アルゴリズムで「もっともらしい成功」を出してはならない。許容される結果は `eligible: false`、明示エラー、`501` 型の fail-closed のみ。
- `.cursor/rules/fallback.mdc:16-23`（原則）、`:25-29`（許容パターン）、`:31-35`（禁止例）。禁止例に「最適化 API 失敗時に温度ウィンドウ走査へ切り替えて `eligible: true` を返す」（`:33`）と「Gateway / Adapter で例外を握りつぶし、デフォルト値で成功っぽく見せる」（`:34`）がある。ドメイン外（エッジ・アダプタ）の握りつぶしは `:34` が根拠になる。
- `.cursor/rules/no-convenience-tech-debt.mdc`: 規約違反は残置しない。「小さいから後回し」は根拠にならない。ドキュメントやコメントの一言追記だけでは解消済みとして扱わない。
- `docs/architecture/LAYER-RULES.md`: R0（Policy が検証を持つ）、R5（結果は output port の `on_success` / `on_failure`。rescue-as-control-flow 禁止）、R7（HTTP エッジは薄く）。
- `.cursor/rules/evidence-before-design-and-implementation.mdc`: 確実性か再現性のどちらかを満たすまで設計・実装しない。
- `.cursor/rules/project-necessary-code-only.mdc`: 依頼・規約・再現済み不具合に結びつかない成果物は書かない。使われないコードは残さない。
- `.cursor/skills/tdd-on-edit/SKILL.md` と `.cursor/skills/test-common/SKILL.md`: 実装前に RED を作り `test-common` のスクリプトで確認する。

### 1.2 判定の定義

| 判定 | 意味 |
| ---- | ---- |
| 修正する | 握りつぶし・代替値を除き、失敗を `Result` または明示結果で伝播する。 |
| 削除する | 本番から到達しない、または正規実装との二重実装であるため、コードごと削除する。 |
| 許容（限定） | §0 の 2 に該当する。理由をコードで確認済み。 |
| ユーザー確認 | 事実だけでは決まらない。§7.1 に理由と推奨を書く。 |

第 1 版の「違反確定 / 仕様上許容 / 要判断」は、§2.1 の「旧判定」列でのみ参照する。

### 1.3 結果の要約

- 8 項目はすべて「修正する」または「削除する」に確定した。「許容」に残る項目はない。内訳: 削除する = 項目 2・3・6・7、修正する = 項目 1・4・5・8。
- **項目 3（その場予測）:** 二択のうち**明示失敗（フォールバックと永続化の削除）を推奨**とした。理由は §3.3。要点は、(a) 予測の生産者は最適化チェーンで、その場計算は二重実装であること、(b) その場計算は最適化チェーンとロックを共有せず競合し得ること、(c) 本番配線では「主経路」がスタブで、その場計算が唯一の実計算経路なのに検証を欠くこと。
- **項目 4:** 第 1 版が「許容」とした「optimizing でない」分岐を再確認した。停止自体は正常だが、(a) 無言で止まること、(b) チェーン内側の再チェックが `Ok(())` を返し、実行されなかった工程が成功として記録されること、の 2 点は許容できない。修正対象に含めた（§3.4）。
- **項目 6:** 期間未指定の既定値だけでなく、`with_private_planning` 全体が本番から呼ばれない（`PublicPlanCreateInteractor` が常に `"public"` を渡す。`public_plan_create_interactor.rs:113`）。削除が妥当（§3.6）。
- **項目 7:** `WindowService::call` の呼び出し元はテストのみ。削除する（§3.7）。
- 依頼外の A〜G は、厳格方針のため本課題に含めた。A は 05-B、B は 05-A と同一箇所であり、そちらで実施する（§2.2）。C・D・E・F は本書で実施する。G はクラス S に統合した。
- 新たに H 系 12 件（うち 3 件 H9・H10・H11 はユーザー確認。H12 は 05 から引き継いだ未割当の 3 点で、判定は監査後）とクラス S を確認した（§2.3）。`unwrap_or*` / `.ok()` の全数は本書では調査していない。監査の手順と基準を §2.4 に定め、実装ステップ 0 に置いた。
- ユーザー確認は 5 件のみ（§7.1）。
- **既に固定されているテスト（第 3 版）:** master の直近 15 コミット（#1330〜#1344）のうち、テストを足した #1338〜#1344 と、#1330〜#1333・#1337 が、8 項目のうち項目 3・4・5・7 と、A・B・C・F・H1・H8・H9 の現状挙動を特性化テストで固定している。#1342〜#1344 の一部のテストには、本書を指すコメント（`docs/spec-defects/06`）が付いている。厳格方針ではこれらの表明が「失敗するのが正」の挙動を固定しているため、対応する実装変更と同じコミットで反転または削除する前提とした。項目別の一覧は §2.5、TDD 計画への反映は §5 に記した。項目 1・6・8、D、E、G、S、H2〜H7・H10 には、直近の追加で固定されたテストが無い（項目 1 は #1307 のインラインテストが代替 Crop を固定している。項目 2 は `entry_schedule.rs` のインラインテストが成功系だけを固定している。§2.5）。

---

## 2. 判定表

### 2.1 依頼された 8 項目

| # | 項目 | 旧判定 → 確定判定 | 根拠 file:line | 本番経路到達性 | 重大度 |
| - | ---- | ----------------- | -------------- | -------------- | ------ |
| 1 | `load_crop_entity_for_optimize` が `find_by_id` の Err で `is_reference: true` の代替 Crop を生成 | 違反確定 → **修正する**（再読込ごと廃止。案 A で確定。§3.1） | `crates/agrr-server/src/entry_schedule.rs:291-299`（`unwrap_or_else` は `:298`）。既存テストがこの代替を表明: `entry_schedule.rs:993-1007` | 到達する。`GET /api/v1/public_plans/entry_schedule/crops/{id}`（`:476-514`）と `.../crops`（`:590-599`）が `OptimizeRunner::call`（`:314-315`）経由で呼ぶ。発火条件は DB 読取エラー（頻度は低い） | 中 |
| 2 | 温度要件取得失敗を `.ok().flatten()` で握りつぶす | 違反確定（現状は実害なし）→ **削除する**（温度読込チェーンごと。§3.2） | `entry_schedule.rs:167-171`。Err を `None` に潰す（`fallback.mdc:34`） | 関数自体は到達する（`entry_schedule.rs:160-181` は最適化経路の `crop_gw`、`:318-320`）。ただし `temperature_requirement` を読む本番コードは `WindowService` のみで、それは項目 7 の通り本番から呼ばれない。結果に影響しない | 低 |
| 3 | 主経路が `None` のとき `fetch_fallback_weather_payload` でその場予測して 200 を返す | 要判断（一部は違反確定: 検証欠落）→ **削除する**（その場予測と永続化を削除し、予測未生成は明示失敗。§3.3） | `field_cultivation_climate_data_interactor.rs:264-293`、`:382-467`。正規経路: `weather_prediction_interactor.rs:206-228`、`:277-330`、`:381-422` | 到達する。`GET .../field_cultivations/{id}/climate_data`（公開・非公開の両方。`crates/agrr-server/src/field_cultivation_climate.rs:130-142`）。`work_record_climate_snapshot.rs:60-79` も同じ配線 | 中 |
| 4 | `plan_still_optimizing(...).unwrap_or(false)` | 違反確定（DB エラー分岐のみ）。「status が optimizing でない」「行なし」分岐は仕様上許容 → **修正する**（DB エラーは Err。非 optimizing は観測可能な正常停止。内側の再チェックは `Err` にする。§3.4） | `crates/agrr-server/src/optimization_chain_phase.rs:33-43`。呼び出し元: `:57`、`optimization_chain_run.rs:434-436`、`task_schedule_generation.rs:218-220` | 到達する。最適化ジョブチェーン全段のガード（`optimization_job_chain.rs:84-300`） | 中 |
| 5 | `FieldsAllocation::allocate` が `total_area <= 0` または作物なしで「デフォルト作物」・面積 `max(100)` を補う | 違反確定 → **修正する**（不正入力は `Err`。§3.5） | `crates/agrr-domain/src/cultivation_plan/calculators/fields_allocation.rs:22-35`。呼び出し元の警告ログのみで許容: `cultivation_plan_initialize_interactor.rs:233-242` | 到達しない。`total_area <= 0` は `:132-139` で先に失敗し、作物なしは `public_plan_create_interactor.rs:92-100` で先に失敗する（第 1 版は `:35-46` と記載していたが、実際の該当は `:92-100`。面積の検査は `:84-87`）。`FieldsAllocation` の他の呼び出し元は無い（`rg` 確認） | 低 |
| 6 | private plan で計画期間未指定のとき start/end とも `clock.today()` | 違反確定（潜在）→ **削除する**（`with_private_planning` ごと。§3.6） | `cultivation_plan_initialize_interactor.rs:194-200`（`:197-198`）。`with_private_planning` は `:92-110`。エッジの呼び出し `public_plans.rs:405-412`（`user_id.unwrap_or(0)` は `:406`） | 到達しない。本番の呼び出し元 `PublicPlanCreateInteractor` は `plan_type` に常に `"public"` を渡す（`public_plan_create_interactor.rs:107-116`）ため、`public_plans.rs:405` の else 分岐自体が実行されない。`with_private_planning` を呼ぶテストも無い（`rg with_private_planning crates` で定義と `public_plans.rs:405` の 2 件のみ） | 低 |
| 7 | `WindowService` が温度しきい値走査で常に `eligible: true`（rule `temperature_thresholds`） | 違反確定 → **削除する**（§3.7） | `crates/agrr-domain/src/cultivation_plan/interactors/entry_schedule/window_service.rs:88-113`（`eligible: true` は `:106`）。`fallback.mdc:33` の禁止例に文言が一致 | 到達しない。`WindowService::call` の呼び出し元は自身のテスト（`crates/agrr-domain/test/cultivation_plan/interactors_entry_schedule_window_service_test.rs`）のみ。`rg '\bWindowService\b' crates` で確認。型 `DateRange` / `WindowServiceResult` は本番で使用（`entry_schedule_optimize_interactor.rs:14`、`entry_schedule_phase_timeline.rs:8`） | 低（到達不能だが禁止例そのもの） |
| 8 | `serde_json::to_value(..).unwrap_or_else(\|_\| json!([]))` と `presenter.body.unwrap_or_default()` | 違反確定（低。実害なし）→ **修正する**（クラス S の一部。§3.8） | `crates/agrr-server/src/weather_reschedule_proposals.rs:98-100`（同型が `:102-104` にもある）、`:141`。対比: preview は `None` を 500 にしている `:224-231` | `unwrap_or_else`: 型が導出 Serialize のみ（`weather_reschedule_proposal_read.rs:6-23`、`weather_reschedule_proposal_preview_read.rs:9-22`）のため失敗しない。`unwrap_or_default`: interactor は `Ok(())` を返す前に必ず `on_success` を呼ぶ（`weather_reschedule_proposals_list_interactor.rs:66`）ので `None` にならない。ハンドラは到達する | 低 |

表の「根拠 file:line」のうち、既存テストが現状挙動を固定している項目（項目 1・3・4・5・7）は、固定しているテストの関数名と行を §2.5 にまとめた。第 3 版で、項目 3・4・5・7 に直近のテストが加わった。

### 2.2 依頼範囲外で見つけた同種の握りつぶし A〜G（再確認と確定）

ID の対応に注意: 本書の A は 05 の B、本書の B は 05 の A（05 は「climate の progress 失敗」を A、「entry-schedule の作物要件」を B とする）。05 は本書の C・D・E・F・G を「06 に引き継ぐ」箇所として挙げている（05 §10）。

| ID | 箇所 | 再確認した事実 | 確定 | 扱い |
| -- | ---- | -------------- | ---- | ---- |
| A | `entry_schedule.rs:127-142`（`AgrrCropBuilder::build_from`。メソッドは `:133-141`） | `.ok().flatten().unwrap_or(json!({}))`（`:138-140`）を再確認。`build_crop_agrr_requirement` の Err と `Ok(None)` の両方を `{}` にして最適化デーモンへ渡す。ポートが `Value` 返しで Err を運べない（`crates/agrr-domain/src/shared/ports/crop_agrr_requirement_builder_port.rs:7-10`） | 修正する | **05-B で実施**（05 §5.B の案 B-1）。本書では二重に直さない。ただし `OptimizeRunner::call` を項目 1 と共有するため、コミット順を §6 で調整する。現状挙動は `interactors_entry_schedule_optimize_interactor_test.rs` の `forwards_empty_crop_requirement_when_builder_swallows_missing_requirement`（`:1042`）が固定している（§2.5） |
| B | `field_cultivation_climate_data_interactor.rs:308-311` | `calculate_progress` の Err を `{"progress_records": []}` にする。05 §2.A の調査で、この値は mapper で手計算 GDD の非空 `gdd_data` になることが分かっている（`field_cultivation_climate_data_mapper.rs:187-188`。05 の記載） | 修正する | **05-A で実施**（05 改訂 2 は `on_failure(FieldCultivationClimateFailure)` を追加する。第 2 版が書いた `on_progress_unavailable` は 05 から消えた）。本書では二重に直さない。現状挙動は `interactors_field_cultivation_climate_data_interactor_test.rs` の `presents_manual_gdd_when_progress_gateway_fails`（`:668`）ほかが固定している（§2.5） |
| C | 同 `:361-362` | `load_plan_prediction_payload(...)?.unwrap_or(json!({}))`。メタデータはあるがストアにペイロードが無い（`Ok(None)`）とき `{}` になり、観測値のみのマージで 200 になり得る（`merge_cached_with_observed`: `field_cultivation_climate_weather_payload_mapper.rs:79-114` は、キャッシュ側の `data` が無ければ空配列として扱い、観測値が空でなければ観測値だけの `data` を返す）。`skip_merge` のときは `{}` が `WeatherPayloadInvalidError` になる（`:329-332`、`:503-515`）。ストア読取の Err は `?` で伝播済み（`:361`）。ストア実装の 1 つは GCS（`crates/agrr-adapters-gcs/src/predicted_weather_store_gateway.rs:33`）。ペイロード欠落は「メタデータとストアの不整合」であり、業務上の「無い」ではない | 修正する | **本書で実施**（項目 3 と同一変更）。`Ok(None)` を明示エラー（予測ペイロード欠落）にする。固定済みのテストは、観測値を足さない分岐（`skip_merge`。栽培期間が今日以降）だけで、`{}` が `WeatherPayloadInvalidError` になることを表明する（`:869`、`:940`）。観測値を足す分岐（期間が過去を含み、観測値が非空）で `{}` が観測値だけの成功になる点は、`merge_cached_with_observed` が観測値の `data` を採るコード（`field_cultivation_climate_weather_payload_mapper.rs:79-100`）の読解のみで、テストでは固定されていない（§2.5） |
| D | `entry_schedule.rs:445-449`（`stage_rows`）、`:481`（resolve interactor の `.ok()`）、`:567-569`（`list_by_is_reference(...).unwrap_or_default()`）。同ファイルで追加確認: `:434-442`（`load_farm` が全 Err を 404 `farm not found`）、`:264-265`（`load_weather_location_by_id` の Err を `WeatherLocationMissingError`＝422 にする）。同型: `masters_crops.rs:111`（`list_by_crop_id(id).unwrap_or_default()`。08 §R8 が 05/06 に判定を委ねた箇所） | いずれも DB 読取エラーを「空リストの 200」「404」「422」に変える。`stage_rows` はポート `EntryScheduleCropGateway::list_by_crop_id -> Vec<CropStageRow>`（`crates/agrr-domain/src/public_plan/ports/entry_schedule_crop_gateway.rs:5`）が Err を運べないことが構造的原因。`EntryScheduleFailureKind::InternalError` は既にあり、ハンドラで 500 になる（`entry_schedule.rs:393-396` の `_` 分岐） | 修正する | **本書で実施**。ポートを `Result` にし、`RecordNotFoundError` だけ 404、それ以外は 500（`masters_crops.rs:111` は既存の `internal_error()` を使う）。失敗本文は 07 の契約に従う。新しい 500 は `api_error.rs` の `internal_error()`（`errors: ["internal"]`）に揃え、既存の `error` を返す 404 などは 07 の S1 で `errors` が追加される区分 A（07 §2.7 の #1、#15）。`entry_schedule.rs:402` の `error_key` は付加情報として据え置く（07 の Q10、C8）。`weather_location_required`（`:263-265` の `WeatherLocationMissingError`）は、行なしの場合だけ 422 のまま、DB エラーは 500 にする。フロントは 422 の `weather_location_required` を `errors` の要素で比較する（07 §3.7.1）ため、行なしの本文は変えない |
| E | `field_cultivation_climate.rs:89-92`、`work_record_climate_snapshot.rs:74-77` | `StoreBackedWeatherPredictionService` がストア読取の Err を `.ok().flatten()` で `None` にし、その場予測へ落とす | 削除する | **項目 3 で `StoreBackedWeatherPredictionService` ごと消える**（`invoke_plan_prediction` が唯一の使用箇所。§3.3） |
| F | `entry_schedule_optimize_interactor.rs:199-208` | `cultivation_method` が `None` のとき、ステージ名（「定植」「植え付」。`stage_role_resolver.rs:13`）から移植を推定し、なければ直播にする。`ARCHITECTURE.md:106-111` が禁じる「fuzzy match, fixed defaults」に該当する。列は NULL 許容（`crates/agrr-migrate/migrations/schema/V26__crops_cultivation_method.sql`）。ただし参照作物の fixture は 3 ファイル（`db/fixtures/reference_crops.json` 15 件、`us_reference_crops.json` 30 件、`india_reference_crops.json` 30 件）すべて `cultivation_method` が設定済みで、NULL は 0 件（`python3` で集計）。`scripts/production-data-migrate-inner.sh:40` は jp の `cultivation_method` を fixture から補修する | 修正する | **本書で実施**。推定を削除し、`None` は `failed_result("missing_cultivation_method")`（`:202` に既存）にする。事前確認として本番 DB の参照作物の NULL 件数を読み取り専用で確認する（§6 ステップ 0）。推定を表明する既存テスト 2 件（`interactors_entry_schedule_optimize_interactor_test.rs:574`、`:641`。#1309 から存在）は反転する。`None` かつステージなしを `missing_cultivation_method` とする既存テスト（`:542`）は、そのまま維持する（§2.5） |
| G | `crates/agrr-server/src/account.rs:39` | `serde_json::to_value(export).unwrap_or(json!({}))`。`UserDataExport` は導出 Serialize で、フィールドは `String` と `Vec<serde_json::Value>`（`crates/agrr-domain/src/user_account/dtos/user_data_export.rs:6-12`）のため失敗しない。ただし失敗すれば、データ持ち出し（アカウント削除前のエクスポート）が空の `{}` で 200 になる | 修正する | **クラス S に統合**（§2.3） |

### 2.3 依頼外で新たに確認した同種箇所

#### クラス S: 失敗し得ないシリアライズ・書式化の握りつぶし

型を確認した範囲では失敗しないが、失敗すれば「空の成功形」になる。到達可否に関係なく、厳格方針では同じ修正（`Result` の伝播）に揃える。

| ID | 箇所 | 失敗時の成功形 | 呼び出し側が Result を返せることの確認 |
| -- | ---- | -------------- | -------------------------------------- |
| S1 | `weather_reschedule_proposals.rs:98-100`、`:102-104`（項目 8） | 提案なし `[]` / 空のプレビュー `{}` の 200 | ハンドラは `Result<Json<Value>, (StatusCode, Json<Value>)>`（`:110`）。既存の 500 形 `{"errors": ["internal_error"]}`（`:150-153`） |
| S2 | `weather_reschedule_proposals.rs:141`（項目 8） | `on_success` が呼ばれなかったときの空配列 200 | 同上。preview は `None` を 500 にしている（`:224-231`） |
| S3 | `account.rs:39`（G） | エクスポートが `{}` の 200 | `ExportPresenter::on_failure` が 422 を返す形が既にある（`account.rs:43-48`）。`on_success` 内で変換できないため、型付き `Json<UserDataExport>` を返すか、失敗を `on_failure` 経由にする |
| S4 | `crates/agrr-domain/src/user_account/interactors/user_data_export_interactor.rs:36` | `exported_at` が空文字のエクスポート | `call` は `Result` を返す（`:31`）。書式化の Err を `on_failure` にする |
| S5 | `crates/agrr-domain/src/crop/interactors/crop_create_interactor.rs:107-108`、`crop_update_interactor.rs:91-92` | `groups` の保存値が `"[]"`（書き込みデータの無言の欠落） | `call` は `Result` を返す（`crop_create_interactor.rs:55-58`、`crop_update_interactor.rs:39`） |
| S6 | `crates/agrr-domain/src/public_plan/interactors/public_plan_create_interactor.rs:103-105` | 12/31 の構築失敗を開始日で代替（定数入力で失敗しない） | `call` は `()` を返し `output_port.on_failure` を持つ（`:62-` の各分岐）。失敗を `on_failure` にするか、`Result` を返さない構築に変える |

`unwrap_or_else(|_|` の非テスト箇所は、`agrr-domain/src` で 4 件（B、S4、S5 の 2 件）。B は 05-A が、それ以外は S が消す。

#### H 系: その他の確認済み箇所

| ID | 箇所 | 確認した事実 | 確定 |
| -- | ---- | ------------ | ---- |
| H1 | `crates/agrr-domain/src/cultivation_plan/calculators/agrr_crops_config_calculator.rs:31-33` | `requirement` が `None`（または非オブジェクト）でも `json!({})` に `crop.crop_id` だけを足して agrr に渡す。`has_growth_stages` が真なら `Ok(None)`（ステージはあるが温度・熱要件が揃わない）でも通る（`plan_allocation_adjust_read_snapshot_parts.rs:81-86`、`plan_allocation_adjust_read_gateway.rs:399-413`）。呼び出し元は 2 つ: `plan_allocation_adjust_interactor.rs:643`、`crates/agrr-server/src/plan_allocation_candidates.rs:81`。05 §2.B-5 が「未確認」とした隙間を、コードで確認した。A（05-B）と同じ `{}` の握りつぶし | 修正する。要件なしの作物は agrr に渡さず、明示失敗にする（失敗の種別は 07 のエラー契約と合わせる。既存の `crop_requirement_error` の文言は `config/locales/ja.yml:83`） |
| H2 | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_allocation_adjust_read_gateway.rs:338-346`、`:347`、`:395-397` | 日付が取れない栽培行を `continue` で無言に除外する（NULL と不正文字列を区別しない）。`optimization_result` の JSON 不正を `.ok()` で `None` にする。`groups` の JSON 不正を空配列にする。除外された栽培行は agrr の調整入力から消える。`field_cultivations.start_date` / `completion_date` は NULL 許容（`V1__baseline.sql:129`）のため、NULL の行を除く挙動が仕様かは未確認 | 一部修正する。不正な日付文字列と不正 JSON は Err にする。NULL 日付の扱いは仕様確認を要する（§7.2 R10） |
| H3 | `crates/agrr-server/src/public_plans.rs:375-376` | `area_per_unit` / `revenue_per_area` が NULL の作物を 0.0 として計画に登録する。列は NULL 許容（`V1__baseline.sql:72`）。参照作物の fixture は 3 ファイルとも NULL が 0 件（`python3` で集計） | 修正する。NULL は計画作成の失敗にする。事前確認として本番 DB の参照作物の NULL 件数を確認する |
| H4 | `entry_schedule.rs:86-93`（`FarmWrap::latitude` / `longitude` / `region`）、`:471`、`:566` | 農場の緯度・経度が NULL のとき `0.0` を返し、show の応答に `latitude: 0.0` を出す（`entry_schedule_show_interactor.rs:140-141`）。list は生の `farm.latitude` を出す（`entry_schedule.rs:627-630`）ため、同じ農場で show は `0.0`、list は `null` になる。`region` は `"jp"` を補う | 緯度・経度は修正する（`Option` を返し、list と同じく `null` を出す）。`region` の `"jp"` は、NULL の農場が実在するかを事前確認して決める（実在しなければ削除、実在すれば §0 の 2 の既定値として記録） |
| H5 | `optimization_chain_run.rs:284`、`:445`、`:457`、`task_schedule_generation.rs:221` | `advance_phase` の Err を `let _ =` で捨てる（4 件中 3 件）。`:445` は `plan.status` が `None` のとき `"optimizing"` を補う（DB 列は NOT NULL: `V1__baseline.sql:93`。エンティティが `Option` のため補っている）。`:457` は finalize 拒否時の失敗フェーズ遷移を捨てるため、遷移に失敗するとプランが `optimizing` のまま残る。対比: `optimization_chain_phase.rs:81-99` は同じ遷移の Err をログする | 修正する。遷移の Err は `optimization_chain_phase.rs:81-99` と同じ形でエラーログを出す。`status` の `None` は `Err` にする |
| H6 | `task_schedule_generation.rs:240`、`:262` | 再生成ジョブの `run_task_schedule_regen_if_current` の結果を `let _ =` で捨てる（ログなし）。Err がタスクスケジュールの同期状態に反映されるかは、同期 interactor を読んでいないため未確認 | 修正する（最低限エラーログ。同期状態への反映は実装時に確認） |
| H7 | `crates/agrr-domain/src/shared/ports/interaction_rule_agrr_format_builder_port.rs:9`（`build_from -> Value`） | 05 が「失敗表現なし、実害は未確認」と記した同形ポート。`rg InteractionRuleAgrrFormatBuilderPort` の結果は、定義ファイルと `shared/ports/mod.rs:8, :21-22` の再エクスポートのみ。実装も使用箇所も無い | 削除する（`InteractionRuleAgrrFormatSource` も同ファイルで、同様に使用箇所が無いことを実装時に再確認） |
| H8 | `crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:76-`（`predict` の `.ok()?`）、`crates/agrr-adapters-sqlite/src/field_cultivation/weather_data_from_storage_gateway.rs:54`、`:58`、`:65`（緯度・経度 `0.0`、タイムゾーン `"Asia/Tokyo"` の補完） | 項目 3 のその場予測の部品。`predict` は agrr の CLI を直接起動する、正規経路（`PredictionDaemonGateway`）とは別の予測実装で、一時ファイルの書き込み失敗を `None` にする。`format_for_agrr` の呼び出し元はフォールバックだけ（`.format_for_agrr(` の使用は `field_cultivation_climate_data_interactor.rs:462` の 1 件） | 削除する（項目 3 と同じ変更） |
| H9 | `work_record_create_interactor.rs:158-164`、`work_record_update_interactor.rs:82-84`、`work_record_climate_snapshot.rs:39`（`on_error` が空実装）、`:150`（`empty()` を返す） | 気象スナップショットの `lookup` の Err と、`on_error` による「気象なし」を区別せず、`gdd_at_actual` / `weather_snapshot` を `None` にして記録を保存する。`None` は代替値ではなく「無い」だが、失敗と「該当なし」が区別されない | ユーザー確認（Q2。05 の確認 3 と同一の決定） |
| H10 | `crates/agrr-domain/src/weather_data/interactors/weather_prediction_interactor.rs:236`、`:240`、`:430`、`:434`、`crates/agrr-server/src/adjust_weather_prediction.rs:118`、`:142` | キャッシュの読取 Err を「キャッシュなし」として扱い、再計算に進む。再計算は検証込みの正規経路で、Err はそちらで伝播する。成功を装う値は作られないが、読取エラーの原因が隠れる | ユーザー確認（Q4） |

### 2.4 範囲の線引きと全数調査

**含める基準（厳格方針）:** Err（または不正値）を捨てて、代替値・既定値・空の成功形にするコード。到達可否は問わない。

**含めない基準（§0 の 2 の許容）と、確認した実例:**

- 拒否側に倒れる既定値: `parse_api_key_scopes_json`（`crates/agrr-domain/src/shared/dtos/masters_api_scope.rs:53-66`）は、空・不正 JSON を空スコープにする。空スコープは権限なしであり、成功を装わない。03 §2.4 が NULL スコープを全拒否と記載している。
- 既定値の後段で明示拒否される場合: `add_field_interactor.rs:72-75`。

**全数調査の扱い:** 本書で確認した箇所は上表で確定した。それ以外は、実装ステップ 0 の監査で分類する。監査の基準は上の「含める基準」で、出力は本書の §2.3 への追記（または課題化）とする。規模の目安は次のとおり（`rg -n`、テスト込みの粗い数）。

| クレート `src` | `unwrap_or_else(\|_\|` | `unwrap_or_default()` | `let _ = ` |
| -------------- | ---------------------- | --------------------- | ---------- |
| agrr-server | 28（18 ファイル） | 48 | 27 |
| agrr-domain | 4 | 57 | 32 |
| agrr-adapters-sqlite | 25 | 45 | 44 |
| agrr-adapters-agrr | 6 | 6 | 10 |
| agrr-adapters-gcs | 5 | 1 | 1 |

このうち、周辺コードを読んでいない未精査の候補（判定はしない）: `agrr-server/src/auth.rs:184`（`session_id.unwrap_or_default()`）、`cable.rs:404`（`member_organization_ids(..).unwrap_or_default()`）、`state.rs:97-104`（環境変数の秘密値を `unwrap_or_default()`）、`work_record_photos.rs:158`、`:302`、`work_records.rs:342`、`:389`、`public_plans.rs:488`、`cultivation_plans_mutations.rs:264`、`crates/agrr-domain/src/weather_data/helpers/predicted_weather_cache.rs:131-134`（降水・日照・風速・天気コードが欠落したとき 0 を補う）、`private_plan_initialize_from_selection_interactor.rs:236-247`（面積が NULL または不正な圃場マスタを無言に除外。全件が除外されたときの挙動は未確認）。認証・秘密値の候補は 02・04・10 の領域と重なるため、突合してから扱う。

---

## 3. 項目ごとの対応方針

### 3.1 項目 1: `load_crop_entity_for_optimize` の代替 Crop（修正する。案 A で確定）

**確認した事実**

- 代替 Crop は `CropEntity::new(crop.id(), crop.name(), None, true)`（`entry_schedule.rs:298`）。`cultivation_method` と `variety` は `None`（`crates/agrr-domain/src/crop/entities/crop_entity.rs:23-47`）。`.unwrap()` は名前が空だと panic する（同 `:30-32`）。
- 呼び出し元の `CropWrap` は既に完全な `CropEntity` を持っている（`entry_schedule.rs:98-124`）。show 経路は `find_crop_record_with_stages` = `find_by_id`（`crates/agrr-adapters-sqlite/src/crop/crop_gateway.rs:117-122`）の結果、list 経路は `list_by_is_reference`（`:380-381`、`CROP_SELECT` は `cultivation_method` を含む `:77`）の結果。**それでも再読込するのは、ポート `EntryScheduleOptimizationRunnerPort::call` が `&dyn EntryScheduleShowCrop`（id と name のみ。`entry_schedule_show_interactor.rs:29-34`、`:48`、`entry_schedule_crop_mapper.rs:36-39`）しか渡さないため。** つまり再読込は設計上の欠陥で、代替 Crop はその失敗を隠している。
- 影響: 最適化デーモンゲートウェイは `crop_name` / `crop_variety` を使わない（`crates/agrr-adapters-agrr/src/entry_schedule_optimization_gateway.rs:65` の `let _ = (crop_name, crop_variety);`）。代替 Crop の実害は `cultivation_method == None` になることで、`entry_schedule_optimize_interactor.rs:199-208` がステージ名から移植/直播を推定する。ステージ名に「定植」「植え付」を含まない移植作物は直播として扱われ、`sowing_windows` を持つ `eligible: true` が返り得る（コード読解による推論。再現は未実施 → §5 の RED では扱わず、再読込の廃止で原因ごと消す）。この推定自体は §2.2 の F で削除する。
- 失敗時の既存の fail-closed 形は用意されている: `failed_result` は `eligible: false` と `reason_parts.source = "agrr_failed"`（`entry_schedule_optimize_interactor.rs:284-296`）。マッパーは `source == "agrr_failed"` を汎用文言にする（`entry_schedule_crop_mapper.rs:200-205`）。i18n キーは `crates/agrr-server/src/locale_catalog.rs:248-254`。

**決定: 案 A（再読込の廃止）**

案 B（`Result` 化して `eligible: false` にする）は、無駄な再読込と DB 読取経路を残すため採らない。案 B は、案 A が実装できないと確認できた場合の代替に限る。

- `EntryScheduleShowCrop`（`entry_schedule_show_interactor.rs:48`）に `variety()` と `cultivation_method() -> Option<CropCultivationMethod>` を足す。
- 第 1 版のリスク R4（`public_plan` → `cultivation_plan` の新規依存）は解消できる。`CropCultivationMethod` は `crate::crop::entities` にあり（`crates/agrr-domain/src/crop/entities/crop_cultivation_method.rs:3`）、`public_plan` は既に `crate::crop` を使っている（`public_plan_wizard_crops_interactor.rs:3`、`public_plan_wizard_crops_output_port.rs:1`）。`EntryScheduleOptimizeCrop`（`cultivation_plan` 側）を `public_plan` が import する必要はない。エッジ（`entry_schedule.rs`）に、`&dyn EntryScheduleShowCrop` を `EntryScheduleOptimizeCrop` に適合させる薄いアダプタを置く。
- `OptimizeRunner::call` の再読込（`:314-315`）と `load_crop_entity_for_optimize`（`:291-299`）を削除する。`CropWrap` の `EntryScheduleOptimizeCrop` 実装（`:112-124`）が未使用になれば、それも削除する（実装時に `rg` で確認）。
- テスト `load_crop_entity_for_optimize_*` の 3 件（`:956-1007`）は削除する。代替を仕様として固定していた `:993-1007` を含む。

**許容の文書化案:** なし。

**ユーザー確認事項:** なし。

### 3.2 項目 2: 温度要件の握りつぶし（削除する）

**確認した事実**

- `entry_schedule_ordered_stage_rows` は `CropStageSnapshot.temperature_requirement` を `.ok().flatten()` で埋める（`entry_schedule.rs:160-181`）。`with_read` は `rusqlite::Result<Option<_>>` を返す（`crates/agrr-adapters-sqlite/src/pool/mod.rs:37-46`）ので、`.ok()` は DB エラーを、`.flatten()` は「行なし」を、区別なく `None` にする。
- 呼び出し側の最適化 interactor は、このメソッドの Err を `failed_result("crop_stage_load_failed")`（`eligible: false`）にする（`entry_schedule_optimize_interactor.rs:152-157`）。
- `temperature_requirement` を読む本番コードは無い: `agrr-domain/src` 内の使用は `window_service.rs:57-58, 74-75` と型定義（`crop_stage_snapshot.rs:10`）のみ。最適化 interactor は `stage_rows` をステージ ID・名前・「定植」名の有無にしか使わない（`entry_schedule_optimize_interactor.rs:159-160`、`:189-192`、`:203-206`、`stage_role_resolver.rs:12-14`）。

**決定: 削除する**（項目 7 の削除を前提にした確定。第 1 版の「保持する場合」の分岐は採らない）

削除対象:

- `load_entry_schedule_temperature`（`entry_schedule.rs:183-203`）と、`entry_schedule_ordered_stage_rows` の温度読込（`:167-171`）。温度読込が消えると `SqliteOptimizeCropGateway.pool`（`:155`）は不要になる（実装時に確認）。
- `CropStageSnapshot.temperature_requirement`（`crop_stage_snapshot.rs:10`）と `TemperatureRequirementSnapshot`（`temperature_requirement_snapshot.rs`。`entry_schedule/mod.rs:4, :10` の再エクスポートを含む）。
- `StageRoleResolver::sowing_stage`（`stage_role_resolver.rs:17`）。使用箇所は `window_service.rs:51` のみ（`rg` で確認）。
- 関連テスト（`entry_schedule.rs:906-953`）と、テスト専用の `temperature_requirements` テーブル作成（`:687`、`:717`）。

実装順序は項目 7 → 項目 2（§6）。

**ユーザー確認事項:** なし。

### 3.3 項目 3: 気象予測の「フォールバック」（削除する。予測未生成は明示失敗）

**確認した事実（依頼文の前提との差分を含む）**

1. **`fetch_primary_weather_payload` が `None` を返す条件。** `plan_predicted_weather_present`（= `source.plan_metadata.is_some()`。`field_cultivation_climate_context_snapshot_mapper.rs:34`）が真なら、キャッシュ済み予測を観測値とマージして必ず `Some` を返す（`field_cultivation_climate_data_interactor.rs:320-321`、`:352-380`）。偽なら `invoke_plan_prediction`（`:336-350`）が `weather_prediction_gateway.predict_for_cultivation_plan` を呼ぶ。`None` になるのは後者が `None` のときだけ。
2. **本番配線では後者は常に `None`。** `StoreBackedWeatherPredictionService::predict_for_cultivation_plan` は `plan_metadata.is_none()` なら即 `None`（`crates/agrr-server/src/field_cultivation_climate.rs:75-94`、`work_record_climate_snapshot.rs:60-79` も同一）。`plan_metadata` は `plan_predicted_weather_present` と同じ値なので、偽の経路では常に `None`。したがって**本番では「主経路」は実質スタブで、`fetch_fallback_weather_payload` が唯一の実計算経路**。
3. **フォールバックの中身。** 学習データ（`FixedAnchors`: 基準日から 20 年前の 1/1〜基準日。`field_cultivation_climate.rs:57-73`）を DB から読み、`pred_days = completion_date - training_end_date > 0` なら `prediction_gateway.predict(..., "lightgbm")` で予測して観測値とマージし、そうでなければ観測値のみを `format_for_agrr` で返す（`field_cultivation_climate_data_interactor.rs:390-466`、`field_cultivation_climate_fallback_horizon_policy.rs:3-9`）。アルゴリズム（`lightgbm`）と学習データ源は正規の `WeatherPredictionInteractor` と同じ（`weather_prediction_interactor.rs:409`、`:285-293`）で、別アルゴリズムへの切替ではなく遅延計算である。ただし `predict` の実装は agrr の CLI を直接起動する別実装（`crates/agrr-adapters-agrr/src/field_cultivation_climate_gateway.rs:76-`）で、正規経路の `PredictionDaemonGateway`（`adjust_weather_prediction.rs:80`）とは別。
4. **正規経路にある検証が無い。**

   | 検証 | 正規経路 | フォールバック |
   | ---- | -------- | -------------- |
   | 学習データが空 / 18 年分（`MINIMUM_TRAINING_DAYS`）未満はエラー | あり（`weather_prediction_interactor.rs:347-361`、定数は `reference_farm_weather_readiness_policy.rs:8`） | なし（`:400-406` は件数を見ない） |
   | 予測日数が要求日数に満たなければエラー | あり（`weather_prediction_interactor.rs:415-419`） | なし（`:413-420` は `Some` なら採用） |
   | マージ後データが目標日まで届くこと | あり（`:305-312`） | なし |
   | `valid_weather_payload`（`data` の有無） | 主経路のみ（`field_cultivation_climate_data_interactor.rs:332`） | 通らない（`:264-293`） |

   結果として、学習不足や予測不足のまま 200 と気温・GDD を返し得る（コード読解による推論）。これは、厳格方針で「検証欠落・失敗を成功形で返す」に該当する。
5. **永続化ステップは常に失敗する見込み（静的読解。未実行）。** フォールバックは `persist_predicted_weather_if_absent` でその場予測を計画の予測として保存する（`:287`、`:481-501`）。フォールバックに入るのは `plan_metadata` が無いときだけなので、保存は毎回試みられる。`persist_plan_prediction` は `build_metadata_from_payload(...).ok_or("failed to build prediction metadata")?`（`crates/agrr-adapters-sqlite/src/field_cultivation/plan_predicted_weather_gateway.rs:53-60`）で、これは `prediction_start_date` / `prediction_end_date` キーが無いと `None` を返す（`predicted_weather_cache.rs:24-25`）。フォールバックのペイロードは両分岐とも、`merge_training_and_future`（`field_cultivation_climate_weather_payload_mapper.rs:116-125`）か `format_for_agrr`（`open_meteo_weather_mapper.rs:30-60`）で組まれ、これらのキーを持たない。よって保存は `Err` になり、interactor は `Err` を返し（`:287` の `?`）、ハンドラは 500 にする（`field_cultivation_climate.rs:227-232`）ように読める。作業記録の経路（`work_record_climate_snapshot.rs:145`）では `lookup` の Err になり、作成・更新側が無視する（`work_record_create_interactor.rs:158-164`）。**実行していないため断定しない。** 削除の判断はこの点に依存しない（(4) の検証欠落だけで違反が確定する）。
6. **予測の生産者は最適化チェーン。** チェーンの `weather_prediction` 工程が `predict_for_cultivation_plan(&plan_weather, None)` を呼び（`optimization_chain_run.rs:389`）、正規の interactor が地点スコープと計画スコープの両方に保存する（`weather_prediction_interactor.rs:217-224`）。計画の複製は予測メタデータとペイロードもコピーする（`plan_save_plan_copy.rs:121-125`）。したがって `plan_metadata.is_none()` は「予測工程が未完了または失敗した計画」を意味する。
7. **その場計算はチェーンと競合し得る。** チェーンは計画単位のロックを取る（`optimization_job_chain.rs:42`、`:230`。`state.plan_optimization_chain_locks.try_acquire`）。`climate_data` のハンドラはこのロックを取らない（`field_cultivation_climate.rs:167-243`）。予測が未生成の間に GET が来ると、チェーンと GET が同じ計画スコープのペイロードを書き得る。
8. `FieldCultivationClimateDataInteractor` にはテストが無い（`crates/agrr-domain/test/field_cultivation/` に該当ファイル無し。R4 にも `climate_data` のテスト無し。`rg climate_data crates/agrr-r4-contract` が 0 件）。

**二択の比較と推奨**

| 観点 | X: 明示失敗（フォールバックと永続化を削除） | Y: 検証を主経路と同等にする（正規の `WeatherPredictionInteractor` を使う） |
| ---- | ------------------------------------------- | ---------------------------------------------------------------------- |
| 検証（学習データ量・予測日数・目標日到達） | 不要（その場計算が無くなる） | 正規経路の検証をそのまま得る |
| 副作用 | GET は読取のみ | GET が予測を生成し、地点・計画の 2 スコープに保存する |
| チェーンとの競合 | なし | ロックを取らないと競合する（事実 7）。取る場合、GET がチェーンの完了を待つ |
| 実行時間 | 即時 | GET が 20 年分の学習と lightgbm 予測を待つ（デーモン未起動なら失敗） |
| 変更範囲 | interactor の依存を 15 から 11 に減らす削除が中心 | ポートを `Result` 化し、エッジに `OwnedWeatherPredictionService`（`adjust_weather_prediction.rs:104-138`）相当の実装を置き、ロックを配線する |
| 責務 | 予測の生産者はチェーンだけ（事実 6） | 生産者が 2 つになる |

**推奨: X（明示失敗）。** 理由は、生産者をチェーンに一本化でき、GET が副作用を持たず、競合の余地が無いこと。Y は、正規経路と同じ検証を得る代わりに、読取エンドポイントに重い書き込みと競合を持ち込む。ユーザーが「予測未生成でもその場で表示したい」と決めた場合のみ Y に切り替える（Q1）。

**削除対象（X）**

- interactor: `fetch_fallback_weather_payload`（`:382-467`）、`assemble_climate_data_from_fallback`（`:277-294`）、`persist_predicted_weather_if_absent`（`:481-501`）、`invoke_plan_prediction`（`:336-350`）、`fetch_primary_weather_payload` の `else` 分岐（`:322-327`）。依存を `weather_prediction_gateway`、`prediction_gateway`、`plan_predicted_weather_gateway`、`anchors_resolver` の 4 つ削除し、15 から 11 にする（`:45-61`）。
- ポート・ゲートウェイ・実装: `FieldCultivationWeatherPredictionServiceGateway`、`FieldCultivationPredictionGateway`（`field_cultivation_weather_prediction_gateway.rs:5-21`）、`FieldCultivationPlanPredictedWeatherGateway`（`find_plan_metadata` も呼び出し元が無い: `rg find_plan_metadata` は trait と実装の 2 件のみ）とその SQLite 実装（`plan_predicted_weather_gateway.rs`）、`FieldCultivationClimateAgrrGateway` の `impl FieldCultivationPredictionGateway`（`field_cultivation_climate_gateway.rs:76-`）、`field_cultivation::ports::WeatherPredictionAnchorsPort` と `WeatherPredictionAnchors`（使用箇所は `FixedAnchors` 2 つとこの interactor のみ。`weather_data::ports` の同名のものは最適化チェーンが使うため残す）。
- エッジ: `FixedAnchors` と `StoreBackedWeatherPredictionService`（`field_cultivation_climate.rs:57-94`、`work_record_climate_snapshot.rs:42-79`）。**§2.2 の E はこれで消える。** エッジの `plan_weather` 変数（`FieldCultivationPlanPredictedWeatherSqliteGateway`）も不要になる。
- 補助: `FieldCultivationWeatherDataGateway::format_for_agrr`（`field_cultivation_weather_data_gateway.rs:15-19`）とその実装（`weather_data_from_storage_gateway.rs:46-90`。緯度・経度 `0.0`、タイムゾーン `"Asia/Tokyo"` の補完を含む: H8）、mapper の `build_observed_agrr_payload_simple`（`:50-`）と `merge_training_and_future`（`:116-`）、`to_cultivation_plan_weather`、`field_cultivation_climate_fallback_horizon_policy.rs` とそのテスト（`policies_field_cultivation_climate_fallback_horizon_policy_test.rs`）。`find_weather_prediction_targets_by_plan_id`（`field_cultivation_climate_source_gateway.rs:18`）は `invoke_plan_prediction` と `fetch_fallback_weather_payload` のみが使うため、削除後に呼び出し元 0 件になるはず（実装時に `rg` で確認し、0 件なら実装 `climate_source_gateway.rs:56-` と共に削除）。
- 上の各項目は、実装時に `rg` で呼び出し元が 0 件になることを確認してから削除する（本書で全件の呼び出し元 0 件を確認したものは、`find_plan_metadata`、`format_for_agrr`、`weather_prediction_gateway` 系のみ）。

**予測未生成・ペイロード欠落の失敗（§2.2 の C を含む）**

- `plan_predicted_weather_present` が偽のとき: 予測未生成の明示失敗。`plan_metadata` があるのにストアに無いとき（C）: ペイロード欠落の明示失敗。どちらも `present` しない。エラー通知は専用の出力ポートメソッドで行い、`status_for_message` の文字列推定（`field_cultivation_climate.rs:102-116`）に頼らない。
- 05 が追加する `on_progress_unavailable` と同型になる。2 メソッドを 1 つの種別付きメソッドに統合するかは、05 の実装時に決める（05 が先。README の着手順）。
- HTTP ステータスとエラーキーは Q1。

**ユーザー確認事項:** Q1（§7.1）。

### 3.4 項目 4: `plan_still_optimizing(..).unwrap_or(false)`（修正する）

**確認した事実**

- 読取は `SELECT status ... WHERE id = ?1`（`optimization_chain_phase.rs:34-41`）。行なしは `QueryReturnedNoRows`、DB 障害はその他の `rusqlite::Error`。`unwrap_or(false)`（`:42`）は両方を「optimizing ではない」にする。
- **「許容」とした分岐の再確認。**
  - ガード（`run_guarded_optimization_step`）が `false` を返すと、工程を実行せずチェーンを止める（`:57-59`）。何も成功として記録されない。ただし**ログも無い**ため、なぜ止まったかを後から追えない。
  - 工程の内側にも同じ再チェックがある。`run_plan_finalize_step`（`optimization_chain_run.rs:434-436`）と `run_task_schedule_generation_step`（`task_schedule_generation.rs:218-220`）は、`false` のとき `Ok(())` を返す。これらは `run_guarded_optimization_step` の内側で実行される（`optimization_job_chain.rs:166`、`:194`）ので、呼び出し側は成功として `notify_orchestration_on_success` を記録し（`optimization_chain_phase.rs:64-67`）、finalize では `"optimization chain finalized"` をログする（`optimization_job_chain.rs:196-198`）。**実行されなかった工程が完了として扱われる。**
  - この 2 つの関数の呼び出し元は、ジョブチェーンと 1 件のテスト（`task_schedule_generation.rs:452`）のみ（`rg` で確認）。
- **DB エラーで停止すると、無言で止まる。** 失敗フェーズへの遷移も、エラーログも無く、プランは `optimizing` のまま残る。**滞留プランを回収する仕組みは、本書で確認した範囲では見つからない。** `rg -i 'stale|reaper|stuck|reconcile|recover|resume|orphan'` を `crates/agrr-server/src` に実行した結果は、`work_records.rs`（更新競合）、`work_record_photos.rs`（写真の掃除）、`masters_crops.rs`、`task_schedule_generation.rs`（タスクスケジュールの stale）のみで、`cultivation_plans.status` を回収するものは無かった。`UPDATE cultivation_plans SET status` というリテラルは `test_support.rs` とテスト内にのみ存在する（`advance_phase` などゲートウェイ経由の更新は別）。

**決定: 修正する**

1. `plan_still_optimizing` を `Result` を返す形にする。結果は「optimizing」「行なし」「optimizing 以外（観測した status）」の 3 値と DB エラーを区別する。
2. `run_guarded_optimization_step`:
   - 「行なし」「非 optimizing」は正常停止として維持するが、**理由付きでログする**（`plan_id`、観測した status）。無言の停止は許容しない（§0 の 2）。
   - DB エラーは、工程の失敗（既存の `Err(e)` 分岐）と同じ扱いにする。エラーログ、`notify_orchestration_on_failure`、`failure_subphase` があれば失敗フェーズへの遷移（best-effort。遷移の Err は `:81-99` の形でログ）。工程は実行しない。
3. 内側の再チェックは残す（`finalize` は `optimization_completion::apply` で破壊的に書くため、ガードとの間の競合から守る価値がある）。ただし `false` のとき `Ok(())` ではなく `Err(String)`（「plan is no longer optimizing」）にする。DB エラーも `Err(String)` にする。
4. H5: `optimization_chain_run.rs:445` の `unwrap_or("optimizing")` を `Err` にし、`advance_phase` の Err（`:284`、`:457`、`task_schedule_generation.rs:221`）は `:81-99` と同じ形でエラーログを出す。
5. `plan_still_optimizing` の rustdoc に「行なし・非 optimizing は正常停止」を書く。ただし、コード変更が本体で、コメントだけでは解消扱いにしない。

**滞留プランの回収機構が無いこと**は、本課題では扱わない（握りつぶしではなく信頼性の課題）。別課題として起票を提案する（§7.2 R5）。

**ユーザー確認事項:** なし（失敗フェーズへの遷移を best-effort にする点は、既存の `:81-99` の慣行に揃える）。

### 3.5 項目 5: `FieldsAllocation` の代替値（修正する）

**確認した事実**

- `allocate` の先頭分岐は、`total_area <= 0.0 || crops.is_empty()` のとき、`crops.first()` か「デフォルト作物」（`id: 0`、`area_per_unit: 1.0`）を作り、面積を `total_area.max(100.0)` にして返す（`fields_allocation.rs:22-35`）。作物なしで `total_area = 30` なら面積 100 になる。
- 呼び出し元は `total_area <= 0` を先に失敗にする（`cultivation_plan_initialize_interactor.rs:132-139`）。作物なしは公開プラン作成が先に止める（`public_plan_create_interactor.rs:92-100` の `crops.is_empty()` → `on_no_crops_failure`。第 1 版の `:35-46` は誤りで訂正した）。この interactor の直接の呼び出し元は `public_plans.rs:385` のみで、`FieldsAllocation` の呼び出し元は interactor のみ（`rg` 確認）。よって本番では代替分岐に入らない。
- interactor の警告ログ（`:233-240`「Creating default field.」）は、この代替を前提にした文言で、同じく到達しない。
- `create_plan_fields` は `within_transaction` の内側で実行される（`:143`）。`Err` を返すと、トランザクションがロールバックされ、`Ok(CultivationPlanInitializeResult::failure(..))` になる（`:155`）。
- `:245-247` の `invalid_field_area` による `continue` は、面積 0 以下のフィールドを無言に飛ばし、フィールド 0 件の計画を成功として作り得る。本番では、`total_area` が `i64`（`public_plans.rs:356`）で正、かつ `field_count` が `total_area / count >= max_area_per_unit`（10 以上）を満たす件数（なければ 1）から選ばれるため、面積は 1 以上になる（`fields_allocation.rs:55-66` の読解）。到達しない。
- `FieldsAllocation` 専用のテストは無い（`ls crates/agrr-domain/test/cultivation_plan` で確認）。

**決定: 修正する**

- `allocate` を `Result` を返す形にし（`total_area <= 0` / 作物なしは `Err`）、代替分岐を削除する。
- interactor は、作物なしを、`total_area` と同じ位置（`:132-139`）で計画作成前に失敗結果にする。`create_plan_fields` は `allocate` の Err を `?` で伝播する。`:233-240` の警告ログを削除する。
- `:245-247` の `continue` は `Err` にする（無言でフィールド 0 件の計画を作らない）。

**許容の文書化案:** なし。

**ユーザー確認事項:** なし。

### 3.6 項目 6: private plan の計画期間既定値（削除する）

**確認した事実**

- `resolve_planning_dates` の private 分岐は、start/end が `None` のとき両方 `clock.today()`（`cultivation_plan_initialize_interactor.rs:194-200`）。期間ゼロ日の計画になる。
- **第 2 版の新しい確認:** 本番の呼び出しは `PublicPlanCreateInteractor` の 1 箇所で、`plan_type` に常に `"public"` を渡す（`public_plan_create_interactor.rs:107-116`）。`PlanInitializerPort` の本番の実装は `SqlitePlanInitializer`（`public_plans.rs:352`）のみ（他はテストの `FakeInitializer`: `interactors_public_plan_create_interactor_test.rs:118`）で、else 分岐（`:405-412`）は実行されない。`with_private_planning` を呼ぶのは `public_plans.rs:405` のみで、テストからも呼ばれない。この else 分岐には `user_id.unwrap_or(0)`（`:406`）もあり、ユーザー ID 0 という架空の値で計画を作る形になっている。
- 対比: public 分岐の `calculate_public_planning_dates`（`:201-207`）は、公開プランの既定期間を返す別仕様。`with_public_planning` は日付を必須で受ける（`:76-90`）。既定期間に頼るのは `new` 単体の使用のみで、その呼び出し元は `agrr-adapters-sqlite` の統合テスト（`cultivation_plan_initialize_integration_test.rs:115`、`:165`、`:235`）に限る。

**決定: 削除する**

- `with_private_planning`（`:92-110`）と、`resolve_planning_dates` の private 分岐（`:195-200`）を削除する。これで `unwrap_or_else(|| clock.today())` は残らない。
- `public_plans.rs:405-412` の else 分岐は、`plan_type` が `"public"` 以外のとき明示的な失敗（`PlanInitializerResult::failure`）にする。`user_id.unwrap_or(0)` は残さない。
- `with_private_planning` の削除で未使用になるフィールド・分岐（`user_id`、`plan_year`、`plan_name` と `plan_type == "private"` の分岐 `:172-180`、`resolve_plan_name`）は、実装時に `rg` で確認して削除する。
- 公開プランの既定期間（`:206`）は、入力省略に対する仕様上の既定で、失敗の代替ではない。本課題の対象外とする。ただし本番の呼び出し元は使わず、統合テストだけが使う（上記）ため、別課題として削除を検討する余地がある（§7.2 R11）。

**TDD:** 到達しないコードの削除であり、振る舞いは変わらない。`.cursor/rules/tdd-on-edit.mdc` の例外（振る舞い不変リファクタ）に当たる。第 1 版でユーザー確認に残していた点は、本番の到達性を確認したため、確認不要とした（§5.6）。

**ユーザー確認事項:** なし。

### 3.7 項目 7: `WindowService` の温度走査（削除する）

**確認した事実**

- 温度しきい値でウィンドウを走査し、`eligible: true` を返す（`window_service.rs:88-113`）。適格日が 0 件でも `true` になる（`sow_ok_dates` / `tr_ok_dates` が空かの検査が無い。`:77-113`）。
- `fallback.mdc:33` と `ARCHITECTURE.md:71` が禁止する形に一致する。ただし `WindowService::call` は本番から呼ばれない（`rg` 確認）。本番の最適化は `EntryScheduleOptimizeInteractor`（agrr の `optimize_period`）で、失敗時は `eligible: false`（`entry_schedule_optimize_interactor.rs:284-296`）。
- 依存: 同ファイルの `DateRange` と `WindowServiceResult` は本番で使われる（`entry_schedule_optimize_interactor.rs:14`、`entry_schedule_phase_timeline.rs:8`、`entry_schedule/mod.rs:11`）。`EntrySchedulePhaseTimeline` 自体には、本番の呼び出し元が無い（非テストの使用は `mod.rs:8` の再エクスポートと自身の定義のみ。`rg` で確認）。ただし fail-closed 違反ではないため、本課題の対象外（§7.2 R6）。
- フィクスチャ文字列 `"window_service"` がテストに残る: `interactors_entry_schedule_phase_timeline_test.rs:87` ほか、`mappers_entry_schedule_crop_mapper_test.rs:204`。

**決定: 削除する**

- `WindowService`（`struct`・`impl`・`day_viable`・`extract_daily_series`・`merge_consecutive_dates`）とそのテストファイル（`interactors_entry_schedule_window_service_test.rs`）を削除する。
- `DateRange` と `WindowServiceResult` は別ファイルへ移す。結果型の名前は、生産者に合わせて `EntryScheduleOptimizeResult` を推奨する（`rg` で同名の既存型が無いことを確認済み。`public_plan` 側の `EntryScheduleWindowResult`（`entry_schedule_crop_mapper.rs:12`）とは別）。最終的な名前は `naming-ules.mdc` に照らして実装時に決める。
- `entry_schedule_crop_mapper.rs:10` の doc コメント（`Ruby: WindowService::Result`）と、テストのフィクスチャ文字列 `"window_service"` を、削除後も意味の通る値に直す。

**ユーザー確認事項:** なし。

### 3.8 項目 8: `weather_reschedule_proposals.rs` の握りつぶし（修正する。クラス S）

**確認した事実**

- `proposals_to_json`（`:98-100`）と `preview_to_json`（`:102-104`）は `serde_json::to_value(..).unwrap_or_else(..)`。対象型は導出 Serialize の `String` / 列挙 / `serde_json::Value` / `Vec` のみ（`weather_reschedule_proposal_read.rs:6-23`、`weather_reschedule_proposal_preview_read.rs:9-22`）で、`to_value` は失敗しない。ただし失敗すれば「提案なし」の 200 や `{}` になり、利用者に誤解を与える。
- `presenter.body.unwrap_or_default()`（`:141`）は、`on_success` が呼ばれなかった場合に空配列の 200 にする。現状 interactor は必ず `on_success` を呼ぶ（`weather_reschedule_proposals_list_interactor.rs:66`）。同ファイルの preview ハンドラは `None` を 500 にしていて（`:224-231`）、扱いが非対称。
- R4 契約に一覧の形の回帰ガードがある: `crates/agrr-r4-contract/tests/contracts.rs:1122-1180`（空配列、401、他ユーザー、霜予報の提案形）。preview には 401 / 不明な提案 / 他ユーザーのテストがある（`contracts.rs:1188`、`:1203`、`:1225`）が、成功時の形を表明するテストは確認できなかった（`rg` で `fn .*weather_reschedule` と `/preview` を確認した範囲）。

**決定: 修正する**

- `to_value` の失敗を握りつぶさず、`internal_error` の 500（既存のエラー形 `{"errors": ["internal_error"]}`: `:150-153`）にする。もしくは型付き `Json<Vec<..>>` を返して axum に直列化させる。どちらも成功時の JSON は不変。
- `:141` は `match presenter.body { Some(p) => .., None => 500 }`（preview `:224-231` と同じ形）にする。
- 同ファイルの `preview_to_json`（`:102-104`）も同時に直す。
- クラス S の残り（S3〜S6。§2.3）も、同じ方針（`Result` を伝播し、既存の失敗形に乗せる）で直す。S3 は `account.rs` で、失敗を空の `{}` の 200 にしない。

**ユーザー確認事項:** なし。

### 3.9 追加発見 A〜G・H 系の対応方針

本課題の範囲に含める（§0 の決定）。ただし A・B は 05 が実施するため、本書は二重に直さない。

**C（`:361-362`）:** 項目 3 の変更に含める（§3.3）。`Ok(None)` を明示エラーにする。

**D（`entry_schedule.rs` ほか）:** `EntryScheduleCropGateway::list_by_crop_id` を `Result<Vec<CropStageRow>, _>` にする（`crates/agrr-domain/src/public_plan/ports/entry_schedule_crop_gateway.rs:5`）。show interactor は Err を `EntryScheduleFailureKind::InternalError` の失敗にする（`entry_schedule_show_interactor.rs:123` の呼び出し）。ハンドラ側は、`load_farm`（`:434-442`）、resolve interactor（`:481`）、`list_by_is_reference`（`:568-570`）、`load_weather_location_by_id`（`:264-265`）で、`RecordNotFoundError` だけ 404（または既存の 422）にし、それ以外は 500 にする。`RecordNotFoundError` をこれらのゲートウェイが返すかは未確認（実装時に確認）。`masters_crops.rs:111` は `?` 相当で既存の `internal_error()` に流す。

**E:** 項目 3 で消える。

**F:** `entry_schedule_optimize_interactor.rs:199-208` の推定を削除し、`None` はすべて `failed_result("missing_cultivation_method")` にする。`StageRoleResolver::has_transplant_stage`（使用箇所は `:204` のみ）とそのテスト（`interactors_entry_schedule_stage_role_resolver_test.rs:62-76`）は、未使用になるため削除する。

**H1:** `agrr_crops_config_calculator::build` は、`has_growth_stages` が真で `requirement` が `None` の作物を、`{}` で通さずに失敗として返す（`Result` 化）。呼び出し元 2 つ（`plan_allocation_adjust_interactor.rs:643`、`plan_allocation_candidates.rs:81`）で、`PlanAllocationAdjustFailure` の新しい種別か既存種別を使う（HTTP ステータスは `preview_failure_status`（`weather_reschedule_proposals.rs:86-95`）の分類に合わせる。種別の名前とエラー形は 07 と合わせる）。

**H2:** 不正な日付文字列と不正 JSON は Err にする。NULL 日付の除外は、仕様（未確定のスケジュールの行がありうるか）を確認するまで変えない（§7.2 R10）。ただし、除外した行数をログするなど無言でなくす。

**H3:** `PublicPlanCrop` から `CultivationPlanInitCrop` に変換する際、NULL の `area_per_unit` / `revenue_per_area` は `Err` にする（`public_plans.rs:375-376` は既に `Result<Vec<_>, String>` 形で `failure(vec![e])` に流れる: `:380-383`）。

**H4:** `EntryScheduleShowFarm::latitude` / `longitude` を `Option<f64>` にし、show の応答を list と同じく `null` にする。

**H5・H6:** §3.4 と §5.4 のとおり。H6 は Err の行き先を確認して、最低限ログする。

**H7:** 削除する。

**H8:** 項目 3 で削除する。

**H9:** Q2。**H10:** Q4。

---

## 4. 共通方針（`unwrap_or` 系の再発防止）

### 4.1 判断基準

- 主経路の失敗は、次の 3 つのどれかにする: 明示エラー（`on_failure` / 4xx・5xx とエラーコード）、`eligible: false` と理由、`501`（`fallback.mdc:25-29`）。
- `Err(_) => デフォルト値` は禁止。「行なし」「`Ok(None)`」が業務上意味を持つ場合のみ `None` を許容し、DB エラーとは別扱いにする（項目 2・4 が該当）。許容する停止や `None` は、観測可能（ログまたは明示結果）にする。
- `unwrap_or*` の「正常な既定値」（ページ幅の既定など、入力の省略に対するもの。例 `entry_schedule.rs:537-538`）は対象外。対象は「失敗を成功に見せる」ものだけ。既定値で埋めても、後段が明示拒否する場合（`add_field_interactor.rs:72-75`）も対象外。
- 到達不能なコードは、修正でなく削除を第一選択にする。

### 4.2 lint・検出スクリプトの再評価と推奨

**既存ガードの仕組み（`scripts/run-architecture-guard-lib.mjs` を読んだ）:**

- ファイル全体を正規表現で検査する（`checkDomainImports` の `readFileSync` + `pattern.test(content)`: `:112-122`、`checkGatewayDefault`: `:145-163`）。行単位の除外機構は無く、除外があるのは R7 のファイル名・ハンドラ名の集合だけ（`R7_EXEMPT_FILES` `:22-32`、`R7_EXEMPT_HANDLERS` `:34-41`）。
- `ruleId` は自由な文字列（`'R1'`、`'FE-COMPONENTS'` など）。`docs/architecture/LAYER-RULES.md` は 100 行の上限があり（`scripts/check-layer-rules-md-lib.mjs` の `MAX_LAYER_RULES_LINES`）、fail-closed の行は無い。ルールを足しても LAYER-RULES の更新は要らない。
- CI で実行される: `.github/workflows/lint.yml:25-26`（ガード本体）と `:28-29`（`node --test scripts/run-architecture-guard-lib.test.mjs`）。テストは規則ごとに一時ディレクトリ木を作って検証する構造（`run-architecture-guard-lib.test.mjs:34-` の R1、R2、R6、R7、FE-*）。`runArchitectureGuard passes on production repo tree`（`:29-32`）が、現行ツリーの違反 0 件を要求する。

**候補の評価（厳格方針のもとでの再評価）:**

| 案 | 評価 |
| -- | ---- |
| `clippy::unwrap_used` | **不採用（変更なし）。** `unwrap_used` は `.unwrap()` を検出するもので、`unwrap_or_else(\|_\| ..)` や `.ok().flatten()` は検出しない。一方 `.unwrap()` は `agrr-server` 217、`agrr-domain` 53、`agrr-adapters-sqlite` 548、`agrr-adapters-agrr` 12 の計 830 件あり（`rg -F -c '.unwrap()'`。テスト込み）、大量の `allow` が要る。CI・スクリプト・`Cargo.toml` に clippy の設定は無い（`grep -rn clippy .github scripts bin Cargo.toml` が 0 件）。 |
| `agrr-domain/src` の非テスト `.rs` で `unwrap_or_else(\|_\|` を禁止する 1 ルール | **推奨（第 1 版の「見送り」から変更）。** 第 1 版は、本課題の範囲外の 3 件が残るため見送った。厳格方針で範囲を広げた結果、`agrr-domain/src` の該当 4 件（B、S4、S5 の 2 件）はすべて本課題または 05 で消える。ルール追加時に違反 0 件にでき、行単位の除外機構も要らない。`agrr-domain/src` のテストは `test/` 配下から `include!` される（`crates/agrr-domain/test/` は走査対象外）ため、テストコードの誤検知も生じない。 |
| `agrr-server` / アダプタ向けの同種ルール | **不採用。** `unwrap_or_else(\|_\|` は `agrr-server` 28 件（18 ファイル）、`agrr-adapters-sqlite` 25 件あり、テスト内の使用を含む。ガードは行単位の除外機構を持たないため、導入するには新しい除外機構が要る（最小ではない）。本課題の修正で該当を減らした後に、残りを監査（§2.4）で分類してから再評価する。 |
| `.ok()` / `unwrap_or_default()` の検出 | **不採用。** `agrr-domain/src` の `.ok()` の大半は、`Option` を返す日付・数値のパース補助（`parse_iso_date.rs:14-18` など）で、正当。`unwrap_or_default()` は domain 57 件、server 48 件で、大半は正当な既定値。正規表現では区別できない。 |
| 各項目の RED テストで固定 | **採用（変更なし）。** 再発防止は個別の観測可能な振る舞いのテスト（§5）で担保する。 |

**推奨（必要最小限）:** `run-architecture-guard-lib.mjs` に 1 関数（`checkDomainDiscardedErrorFallback`）を足し、`agrr-domain/src` の `.rs` に `unwrap_or_else(|_|` があれば `ruleId: 'FAIL-CLOSED'` の違反にする。`run-architecture-guard-lib.test.mjs` に 2 件のテストを足す（違反ありでルールが失敗する。`unwrap_or_else(|| ..)` は通る）。追加は、§6 で該当 4 件を消した後（同じ PR 内の最後のコミット）とし、追加時点で `runArchitectureGuard passes on production repo tree` が通ることを確認する。`|_|` 以外の書き方（`|e|` を使わないなど）は検出できない限界がある。それでも再発しやすい形（引数を捨てる形）を機械的に止められる。

### 4.3 ドキュメント

`ARCHITECTURE.md:69-73` と `:106-111` に規範は既にある。追記は不要（`no-convenience-tech-debt.mdc`: 一言追記は解消扱いにならず、`project-necessary-code-only.mdc`: 重複説明は不要）。

---

## 5. TDD 計画

### 5.0 実行スクリプトの制約（重要）

- 使える入口は `test-common` のスクリプトのみ（`.cursor/skills/test-common/SKILL.md`、`.cursor/rules/test-common-entry.mdc`）。
  - agrr-domain: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh <cargo test の引数>`。中身は `cargo test -p agrr-domain "$@"` と `cargo test -p agrr-migrate --quiet`（`run-test-rust-domain.sh:21-25`）。フィルタは `-- <テスト名>` で渡す。
  - R4 契約: `scripts/run-rust-contract-tests.sh`。
- **`agrr-server` のインラインテスト（`entry_schedule.rs:644-` の `mod tests`、`optimization_chain_phase.rs` の `#[cfg(test)]` など）と `agrr-adapters-sqlite` のテストには、`test-common` の専用スクリプトが無い。** CI も `agrr-server` の単体テストは実行しない（`.github/workflows/rust-domain-test.yml` は `agrr-domain`・`agrr-migrate`・`agrr-adapters-sqlite -- '_gateway_test'`、`.github/workflows/rails-test.yml:56-58` は `agrr-domain` と `agrr-adapters-sqlite -- '_gateway_test'`）。`.cursor/references/CODE_MODIFICATION_SKILLS.md:22` は HTTP エッジの検証を R4 とする。
- `run-test-rust-domain.sh` は引数を `cargo test -p agrr-domain` の後ろへそのまま渡すため、`-p agrr-server` を引数に足せばスクリプト経由で `agrr-server` のテストを流せる可能性がある。**この使い方は未確認**（実行していない。SKILL.md にも記載が無い）。§7.1 の Q3 で扱う。
- したがって RED を置く層は次の順に選ぶ: (1) agrr-domain の単体テスト（fake ゲートウェイ）、(2) R4 契約、(3) `agrr-adapters-sqlite` の `_gateway_test` 接尾辞のテスト（CI が実行する）。`agrr-server` のインラインテストにしか置けないものは、Q3 の回答に従う。
- 実行方法: 出力を `./tmp/{UUID}.log` にリダイレクトしてから `grep`（`AGENTS.md`: テストランナーの出力を同じシェルで `grep` / `tail` にパイプしない）。長時間のコマンドは `process-monitor` スキルで完了を待つ。全体実行後に `test-slow-detection` を実施する。
- TDD の例外（`.cursor/rules/tdd-on-edit.mdc`）: 到達しないコードや使われないコードの削除は振る舞い不変であり、RED を要しない。その場合も、既存テストが GREEN のままであることを検証にする。

### 5.1 項目 1（案 A）

| パス | given / when / then | スクリプト |
| ---- | ------------------- | ---------- |
| `crates/agrr-domain/test/public_plan/interactors_entry_schedule_show_interactor_test.rs`（既存。`entry_schedule_show_interactor.rs:152-156` の include 先） | given: `cultivation_method = Transplant` と `variety` を持つ作物と、その作物を記録する fake `EntryScheduleOptimizationRunnerPort`。when: `EntryScheduleShowInteractor::call`。then: runner が受け取る作物から `cultivation_method()` と `variety()` を読める（ポート拡張の RED。現状はコンパイル不能 = RED） | `run-test-rust-domain.sh -- entry_schedule_show_interactor` |
| `crates/agrr-server/src/entry_schedule.rs` の `mod tests` | `load_crop_entity_for_optimize_*` の 3 テスト（`:956-1007`）を削除する（削除する関数のテスト）。回帰ガードは R4 の show / list（`contracts.rs:4741-4790`）。R4 の実行時に agrr が無い環境の挙動は、`eligible:false` の `disabled` になる（05 §6.B-R4 の記載） | `scripts/run-rust-contract-tests.sh` |

### 5.2 項目 2

RED なし。使われないコードの削除で振る舞い不変（項目 7 と同じコミット系列）。既存テストの削除（`entry_schedule.rs:906-953`）。R4 の show / list（`contracts.rs:4741-4790`）が回帰ガード。

### 5.3 項目 3（と C、E、H8）

新規: `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_climate_data_interactor_test.rs`。`field_cultivation_climate_data_interactor.rs` の末尾に、既存と同じ `#[cfg(test)] mod ..._test_inline { use super::*; include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/..._test.rs")); }` を足す（パターンは `window_service.rs:238-242`）。削除後の `new` は 11 個の引数（`user_id` を除き 10 個の依存）を取るため、fake 群の作成が主な作業量になる。05 の A-R1〜R5 が同じファイルを新設するため、05 が先に作成し、本書は追記する（§6）。

| ID | given / when / then | 現状 | スクリプト |
| -- | ------------------- | ---- | ---------- |
| T3-1 | given: `plan_metadata = None`（予測なし）。天気データの fake ゲートウェイは呼び出し回数を数える。when: `call`。then: 予測未生成の明示失敗が 1 回、`present` は 0 回、天気データの読取は 0 回 | RED（現状は `fetch_fallback_weather_payload` が読取と予測を試み、`present` または Err になる。新しい出力ポートメソッドが無いためコンパイルも通らない） | `run-test-rust-domain.sh -- field_cultivation_climate_data_interactor` |
| T3-2（C） | given: `plan_metadata = Some`、ストアの `read_payload` が `Ok(None)`。when: `call`。then: ペイロード欠落の明示失敗が 1 回、`present` は 0 回 | RED（現状は `{}` と観測値のマージで `present` される） | 同上 |
| T3-3 | given: `plan_metadata = Some`、ストアの `read_payload` が `Err`。when: `call`。then: `call` は `Err`、`present` は 0 回 | 特性化（現状も GREEN。`?` 伝播: `:361`。退行防止） | 同上 |
| T3-4 | given: 有効なキャッシュ予測と観測値、progress が正常。when: `call`。then: `present` が 1 回。予測と観測値がマージされ、`gdd_data` が agrr の値 | 特性化（現状も GREEN。interactor に正常系のテストが無いため、削除の退行防止に必要） | 同上 |
| T3-5（R4・任意） | given: 予測未生成の計画。when: `GET /api/v1/plans/field_cultivations/{id}/climate_data`。then: Q1 で決めたステータスと `error_key` | 任意。R4 の seed（`support.rs:457`、`:933`、`:1192` に `field_cultivations` の seed が既存。作物要件・気象まで揃うかは未確認）が足りなければ、ユニットテストのみ | `scripts/run-rust-contract-tests.sh` |

削除に伴い、`policies_field_cultivation_climate_fallback_horizon_policy_test.rs` を削除する（削除するポリシーのテスト）。第 1 版の T3-0（フォールバックの永続化が失敗することの特性化）と T3-4（アダプタ）は、フォールバック自体を削除するため不要になった。

### 5.4 項目 4（と H5、H6）

`optimization_chain_phase.rs` と `optimization_chain_run.rs`、`task_schedule_generation.rs` は `agrr-server` のインラインテスト（§5.0 の制約）。既存のテスト: `plan_still_optimizing_is_true_only_for_optimizing_status`（`optimization_chain_phase.rs:273-297`）、`run_guarded_optimization_step_skips_when_plan_not_optimizing`（`:300-321`）。

| ID | given / when / then | 現状 |
| -- | ------------------- | ---- |
| T4-1 | given: `cultivation_plans` テーブルを落とした DB。when: 状態の読取。then: `Err` | RED（現状 `false`） |
| T4-2 | given: 存在しない `plan_id`、および status が `failed` / `completed`。when: 状態の読取。then: `Ok`（「行なし」「非 optimizing」の区別を含む） | 既存テストの拡張（GREEN のまま。回帰ガード） |
| T4-3 | given: 状態の読取が Err になる DB。when: `run_guarded_optimization_step`。then: step は実行されず `false`。エラー扱いが観測できる（戻り値の形は実装時に決める。ログの内容は、tracing の捕捉手段が無いため表明しない） | RED |
| T4-4 | given: 非 optimizing のプラン。when: `run_plan_finalize_step` と `run_task_schedule_generation_step`。then: `Err(String)`（現状 `Ok(())` で完了扱いになる） | RED |
| T4-5 | given: `status` が `None` のプランエンティティ（H5）。then: `Err` | RED。ただし DB 列が NOT NULL（`V1__baseline.sql:93`）のため、`None` を作るにはエンティティ側の単体テストで足りる |

### 5.5 項目 5

| パス | given / when / then | 現状 |
| ---- | ------------------- | ---- |
| 新規 `crates/agrr-domain/test/cultivation_plan/calculators_fields_allocation_test.rs`（`fields_allocation.rs` に include を追加） | 作物なし・`total_area = 30` → `Err`。`total_area <= 0` → `Err`。作物 2 件・`total_area = 250` → 通常の配分（特性化。GREEN 維持） | 前 2 つは RED（現状は面積 100 / 代替作物を返す） |
| `crates/agrr-domain/test/cultivation_plan/interactors_cultivation_plan_initialize_interactor_test.rs`（既存。`:171-` の `returns_failure_when_total_area_is_not_positive` と同型） | given: 作物 0 件・`total_area = 50`。when: `call`。then: 失敗結果で、トランザクション内の `create` が呼ばれない | RED |

スクリプト: `run-test-rust-domain.sh -- fields_allocation` と `-- cultivation_plan_initialize`。

### 5.6 項目 6

RED なし。到達しないコードの削除（振る舞い不変）。`with_private_planning` を呼ぶテストが無いため（§3.6）、既存テストは影響を受けない。`run-test-rust-domain.sh -- cultivation_plan_initialize` と、`agrr-adapters-sqlite` の統合テスト（`cultivation_plan_initialize_integration_test.rs`）が GREEN のままであることを確認する（後者は `test-common` に入口が無い。`_gateway_test` 接尾辞ではないため CI も実行しない。確認方法は Q3）。エッジの else 分岐（`plan_type` が `"public"` 以外なら失敗）は `agrr-server` 内の分岐で、`PublicPlanCreateInteractor` からは到達しないため、テストは書かない。

### 5.7 項目 7

RED なし（使われないコードの削除で、本番の振る舞いは不変）。削除後に `run-test-rust-domain.sh` 全体がコンパイル・GREEN であることが検証。`WindowService::call` を呼ぶテスト群（`interactors_entry_schedule_window_service_test.rs`）は削除する。型の移動先でテストが必要な既存の検証が失われないよう、`DateRange` / `WindowServiceResult` を使う既存テスト（`interactors_entry_schedule_phase_timeline_test.rs`、`interactors_entry_schedule_optimize_interactor_test.rs`、`mappers_entry_schedule_crop_mapper_test.rs`）が GREEN のまま通ることを確認する。

### 5.8 項目 8 とクラス S

| 対象 | given / when / then | 現状 | スクリプト |
| ---- | ------------------- | ---- | ---------- |
| S1・S2（項目 8） | 失敗を作れない（導出 Serialize のみ、`on_success` は必ず呼ばれる）ため RED なし。R4 の一覧契約（`contracts.rs:1122-1180`）が回帰ガード。preview の成功時の形を表明する契約が無いため、最小の契約を 1 本足すかを実装時に判断する | 振る舞い不変 | `scripts/run-rust-contract-tests.sh` |
| S4 | 時刻を `OffsetDateTime::now_utc()` で直接取得し（`user_data_export_interactor.rs:34`）、書式化の失敗を作れないため RED なし。既存の `user_data_export` のテストが GREEN のままであることを確認する | 振る舞い不変 | `run-test-rust-domain.sh -- user_data_export` |
| S5 | given: `groups` が直列化できない入力は型上作れない。RED なし。既存テストが GREEN のまま | 振る舞い不変 | `run-test-rust-domain.sh -- crop_create` と `-- crop_update` |
| S3 | `account.rs` は `agrr-server` 内。R4 の既存契約（アカウントのエクスポート）を回帰ガードにする。R4 にあるかは未確認（`rg 'account/export' crates/agrr-r4-contract` を実装時に確認） | 振る舞い不変 | `scripts/run-rust-contract-tests.sh` |

S4・S5 は、`Result` の伝播へ変える際に型が変わるため、既存テストのコンパイルが通ることが実質の検証になる。失敗を作れない以上、RED を捏造しない。

### 5.9 A〜G・H 系

| 対象 | RED | 備考 |
| ---- | --- | ---- |
| C | T3-2（§5.3） | 項目 3 と同じコミット |
| D | `crates/agrr-domain/test/public_plan/interactors_entry_schedule_show_interactor_test.rs`: given: `EntryScheduleCropGateway::list_by_crop_id` が Err の fake。when: `call`。then: `InternalError` の失敗で、`on_success` は呼ばれない（現状は `Vec` 返しのため表現できず、コンパイル不能 = RED）。`masters_crops.rs:111` と `entry_schedule.rs` の各ハンドラは `agrr-server` 内で、R4 の既存契約（`contracts.rs:4741-4790`、masters の crops show）を回帰ガードにする | |
| F | `interactors_entry_schedule_optimize_interactor_test.rs`: given: `cultivation_method = None`、ステージ名に「定植」を含むステージ。when: `call`。then: `eligible == false`、`error_key == "missing_cultivation_method"`（現状は移植として推定され RED）。既存の `:574`（移植を推定）を反転し、`:641`（直播を推定）は、同じ given で失敗になる形に反転する。`has_transplant_stage` のテスト（`interactors_entry_schedule_stage_role_resolver_test.rs:62-76`）は関数と共に削除 | |
| H1 | `calculators_agrr_crops_config_calculator_test.rs`（既存 `:19`）: given: `has_growth_stages = true` かつ `requirement = None` の作物。then: 失敗（現状は `{}` で通り RED）。`plan_allocation_adjust_interactor` のテストに、失敗が出力ポートまで伝わる 1 件 | 失敗の種別は 07 と合わせる |
| H2 | `agrr-adapters-sqlite` の `_gateway_test` 接尾辞のテスト（CI が実行）: given: 不正な日付文字列の栽培行、不正な `groups` JSON。then: Err（現状は無言の除外・空配列で RED） | |
| H3 | `agrr-server` 内（`SqlitePlanInitializer`。§5.0 の制約）。ドメイン側に RED を置けないため、Q3 の回答に従う | |
| H4 | `interactors_entry_schedule_show_interactor_test.rs`: given: 緯度・経度が `None` の農場。then: 応答の `farm.latitude` が `null`（`0.0` ではない。現状は `f64` 返しのためコンパイル不能 = RED） | |
| H5・H6 | §5.4 | |
| H7 | RED なし（使われないコードの削除） | |

---

## 6. 実装ステップ

`crates/agrr-server/**`・`crates/agrr-domain/**` を変更したら、Docker で検証する前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する（`.cursor/rules/docker-dev-agrr-server-rebuild.mdc`）。

| 順 | 内容 | コミット | 根拠 |
| -- | ---- | -------- | ---- |
| 0 | **事前確認（コード変更なし）。** (a) ユーザー確認 Q1〜Q4（§7.1）。(b) 本番 DB を読み取り専用で確認する（`production-primary-sqlite-query` スキル）: 参照作物の `cultivation_method IS NULL` 件数（F）、`area_per_unit` / `revenue_per_area` の NULL 件数（H3）、参照農場の `region` / `latitude` / `longitude` の NULL 件数（H4）。0 件でなければ、データ補修を該当項目の前提にする。(c) §2.4 の監査を行い、結果を §2.3 に追記する。(d) 05 の A・B の実装が先（`docs/spec-defects/README.md` の着手順 05 → 06）。Q に依存しない項目は、(a) の回答を待たずに先へ進める。回答が必要な項目は Q1（項目 3・H1）、Q2（H9）、Q3（H3 のテスト経路）、Q4（H10） | なし | `evidence-before-design-and-implementation.mdc`: 仮説の段階で設計しない |
| 1 | 項目 7: `WindowService` の削除と型の移動。 | 1 コミット | 項目 2 の前提 |
| 2 | 項目 2: 温度読込チェーンの削除（`sowing_stage` を含む）。 | 1 コミット | 項目 7 に依存 |
| 3 | 項目 1（案 A）と D と F と H4。`entry_schedule.rs` と `entry_schedule_show_interactor.rs`、`entry_schedule_optimize_interactor.rs` を触る。05-B（`AgrrCropBuilder`）と `OptimizeRunner::call` を共有するため、05-B の後に行い、衝突を避ける。論理変更ごとに分ける（案 A、D、F、H4 で 4 コミット）。 | 4 コミット | 到達する。項目 2・7 の後にすると差分が小さい |
| 4 | 項目 3（X）と C・E・H8。Q1 の回答後。RED T3-1〜T3-3 → 実装 → GREEN。05-A が同じ interactor と出力ポートを触るため、05-A の後に行う。 | 1〜2 コミット（テスト + 実装。依存の削除を別コミットにできる） | 到達する。ユーザー影響が最大 |
| 5 | 項目 4 と H5・H6（T4-1〜T4-5）。 | 1〜2 コミット | 到達する。完了扱いの誤りを含む |
| 6 | 項目 5（RED T5 → 実装 → GREEN）。 | 1 コミット | 到達不能・低。ただし残置しない |
| 7 | 項目 6（`with_private_planning` の削除と、エッジの else 分岐の明示失敗）と H3（Q3 の回答後）。 | 1〜2 コミット | 到達不能・低 |
| 8 | 項目 8 とクラス S（S1〜S6）と G と H7。 | 論理変更ごとに 1 コミット | 到達不能または低 |
| 9 | H1・H2（失敗の種別は 07 のエラー契約と合わせる）。 | 1〜2 コミット | 07 の決定に依存 |
| 10 | 機械検出の追加（§4.2 の 1 ルールとテスト 2 件）。ステップ 4・8 で該当 4 件を消した後に行う。 | 1 コミット | 追加時点で違反 0 件 |
| 11 | 全体検証: `run-test-rust-domain.sh`（全体）、`scripts/run-rust-contract-tests.sh`、`scripts/run-architecture-guard.sh`、`node --test scripts/run-architecture-guard-lib.test.mjs`、`test-slow-detection`。 | なし | `rails-testing-workflow.mdc`: 個別 GREEN の後に全体実行 |

コミットは論理変更ごとに 1 つ。到達不能な項目も規約違反の残置になるため、`no-convenience-tech-debt.mdc` に従い先送りしない。順序は依存（05 → 06、7 → 2、05-B → 項目 1）と到達性・重大度で決めたもので、日数の見積りはしない。

---

## 7. リスク・未確定事項とユーザー確認

### 7.1 ユーザー確認（厳格方針の下でも残るもの）

| # | 内容 | 残す理由 | 推奨 |
| - | ---- | -------- | ---- |
| Q1 | 項目 3（X）と C で、「予測未生成」「予測ペイロード欠落」を返すときの HTTP ステータスとエラーキー。あわせて、X ではなく Y（GET でその場予測を維持）を望むか | 外部から見える契約の変更であり、07（エラー契約）・08（OpenAPI）に波及する。05 の確認 1（progress 失敗のステータス）と同じ決定に揃える必要がある | X。ステータスは 409、`error_key` は `climate_prediction_unavailable`（ペイロード欠落は別キー）を推奨する。503 は、フロントが warmup として再試行対象に分類する（`frontend/src/app/core/backend-warmup/backend-warmup.ts:98-121`）ため、恒久的な「予測未生成」には向かない。ただし 05 が daemon 不在に 503 を採るなら、本件はそれと種別が違うことを 05 の回答時に併せて確認する |
| Q2 | 作業記録の作成・更新で、気象スナップショットの取得が失敗したときの扱い（H9）。05 の確認 3 と同一の決定 | 記録の可用性と、スナップショットの完全性のトレードオフ。応答の形が変わる。05 の前提では、progress 失敗は agrr デーモン依存であり、失敗を作成の失敗にすると、デーモン停止で作業記録が作れなくなる | 保存は続行し `gdd_at_actual = None` とするが、失敗（Err・`on_progress_unavailable`・`on_prediction_unavailable`）と「該当なし」（気象地点なし、栽培期間なし、作物なし）を区別し、失敗は応答に明示（例: スナップショットが取れなかったことを示すフィールド）とエラーログを残す。`None` は代替値ではなく「無い」だが、失敗を無言にしない |
| Q3 | `agrr-server` のインラインテストと `agrr-adapters-sqlite` の統合テストの実行経路（§5.0）。項目 4・H3・項目 6 の確認に必要 | `test-common` に入口が無く、CI も実行しない。ゲートされないテストを RED/GREEN の根拠にできない。規約（`test-common` のみ）の解釈をユーザーが決める必要がある | (a) `test-common` に `agrr-server` の入口を足す（別課題）。それまでは (c) `run-test-rust-domain.sh -p agrr-server -- <filter>` がスクリプト経由で動くことを確認して使う（未確認。動けば規約の範囲内） |
| Q4 | キャッシュの読取エラーを「キャッシュなし」として再計算に進める挙動（H10）を許容するか | 成功を装う値は作られないが、厳格方針の「握りつぶし」の文言には当たる。Err を伝播すると、キャッシュ基盤の障害が、遅い再計算ではなく失敗に変わり、可用性の特性が変わる | Err を伝播し、`Ok(None)` だけをキャッシュなしとする。厳格方針に沿い、原因を隠さない |

### 7.2 リスク・未確定事項

| # | 内容 | 扱い |
| - | ---- | ---- |
| R1 | Q3 のとおり、`agrr-server` インラインテストの正式ランナーが無い | Q3 の回答まで、該当の RED は「置き場所は決めたが実行経路が未確定」として保留する |
| R2 | 項目 3 の永続化が常に失敗する見込みは、コード読解のみで未実行 | X（削除）の判断はこの点に依存しない（検証欠落だけで違反が確定する）。現状の HTTP 結果を記録したい場合のみ、削除前に特性化テストを書く（任意） |
| R3 | 項目 3 のポート削除の影響範囲。呼び出し元・実装は、`rg` で確認した範囲で `field_cultivation_climate_data_interactor.rs:344` と、実装 2 つ（`field_cultivation_climate.rs:80`、`work_record_climate_snapshot.rs:65`）、`FieldCultivationClimateAgrrGateway`（`:76-`）、`FieldCultivationPlanPredictedWeatherSqliteGateway` | 実装着手時に `rg` で全数確認してから削除 |
| R4 | （第 1 版の R4 は解消）項目 1 の案 A は、`public_plan` → `cultivation_plan` の依存を作らない（§3.1） | — |
| R5 | 滞留プランの回収機構が、確認した範囲で存在しない（§3.4）。DB エラーやプロセス停止で `optimizing` のまま残る計画を回収する手段が無い | 本課題の対象外。別課題として起票を提案する。項目 4 の修正で、少なくともエラーログが残る |
| R6 | `EntrySchedulePhaseTimeline` に本番の呼び出し元が無い（§3.7）。fail-closed 違反ではない | 本課題の対象外。削除を別課題として起票を提案する |
| R7 | 項目 1 の影響（移植作物が直播扱いになる）はコード読解による推論。再現は未実施 | 案 A で原因ごと消える。F で推定も削除する。再現は任意 |
| R8 | H・S 以外の全数調査は未実施（§2.4）。未精査の候補には、認証・秘密値（`auth.rs:184`、`state.rs:97-104`）が含まれる | ステップ 0 の監査で分類する。認証・秘密値は 02・04・10 と突合してから扱う |
| R9 | `ARCHITECTURE.md` に fail-closed の節が 2 つある（`:69-73`、`:106-111`）。内容は同趣旨 | 本課題の対象外（文書の整理は 09 stale-design-docs の範囲。09 の関連課題表が、同じ節を両課題が編集する可能性に触れている） |
| R10 | H2 の NULL 日付の栽培行を除外する挙動が仕様か未確認（`field_cultivations.start_date` / `completion_date` は NULL 許容） | 仕様確認まで変更しない。除外した件数のログは足す |
| R11 | 公開プランの既定期間（`calculate_public_planning_dates`）は、本番の呼び出し元が常に日付を渡すため、統合テストからしか使われない | fail-closed 違反ではない（入力省略に対する既定）。削除を別課題として検討 |
| R12 | 01 の R9 が挙げた `omniauth_session.rs:68-73`（`ensure_personal_organization` の失敗の握りつぶし）は、現行ツリーに該当ファイルが見つからない（`ls crates/agrr-server/src` と `rg personal_organization` で確認） | 本書では扱わない。01 側で位置を再確認 |

---

## 8. 受け入れ条件

### 8.1 共通

- `.cursor/skills/test-common/scripts/run-test-rust-domain.sh`（全体）が GREEN。
- `scripts/run-rust-contract-tests.sh` が GREEN。
- `scripts/run-architecture-guard.sh` が `run-architecture-guard: OK`、`node --test scripts/run-architecture-guard-lib.test.mjs` が GREEN。
- `test-slow-detection` の遅延検知を通過。
- `crates/*` を変更した場合、`rebuild-restart.sh` 後に該当エンドポイントを確認した。
- 各項目の RED が、意図した理由で失敗することを確認してから GREEN にした記録がある（RED が作れない項目 2・6・7・H7 と、失敗を作れない S1・S2・S4・S5 の例外は、§5 に従う）。
- `rg -n 'unwrap_or_else\(\|_\|' crates/agrr-domain/src` が 0 件（§4.2 のルール追加の前提。05-A の B を含む）。

### 8.2 項目別

| # | 条件 |
| - | ---- |
| 1 | `entry_schedule.rs` に `is_reference: true` の代替 `CropEntity` 生成と再読込が残らない（`rg 'CropEntity::new\|load_crop_entity_for_optimize' crates/agrr-server/src/entry_schedule.rs` の本番コードが 0 件）。`EntryScheduleShowCrop` が `cultivation_method()` と `variety()` を持つ。 |
| 2 | 温度要件の `.ok().flatten()` と、`load_entry_schedule_temperature`、`TemperatureRequirementSnapshot`、`StageRoleResolver::sowing_stage` が `crates/` に存在しない。 |
| 3 | `fetch_fallback_weather_payload`、`persist_predicted_weather_if_absent`、`invoke_plan_prediction`、`StoreBackedWeatherPredictionService`、`FixedAnchors`（climate 側）が `crates/` に存在しない。予測未生成と予測ペイロード欠落が、`present` されず、Q1 の回答どおりの明示失敗になる（T3-1・T3-2 が GREEN）。`FieldCultivationClimateDataInteractor` の interactor テストが存在する。 |
| 4 | DB 読取エラーで、プランが無言で `optimizing` に滞留することも、完了として記録されることも無い。「行なし・非 optimizing は正常停止」が理由付きのログとテストで表明されている。`run_plan_finalize_step` と `run_task_schedule_generation_step` が、非 optimizing のとき `Ok(())` を返さない。`advance_phase` の Err を `let _ =` で捨てる箇所（`optimization_chain_run.rs:284`、`:457`、`task_schedule_generation.rs:221`）が無い。 |
| 5 | `FieldsAllocation` に代替作物・`max(100)` の代替が無く、不正入力は `Err`。作物なしは interactor が計画作成前に失敗にする。`invalid_field_area` の `continue` が無い。 |
| 6 | `with_private_planning` が存在せず、`unwrap_or_else(\|\| clock.today())` と `user_id.unwrap_or(0)` が残らない。`plan_type` が `"public"` 以外のとき、エッジは明示的な失敗を返す。 |
| 7 | `WindowService` と `temperature_thresholds` が `crates/` に存在しない（`rg` で 0 件）。`DateRange` / 結果型（`EntryScheduleOptimizeResult` 相当）は本番で引き続き使われる。 |
| 8 | `weather_reschedule_proposals.rs` に `unwrap_or_else(\|_\| json!(..))` と `unwrap_or_default()` が残らない。R4 の一覧契約（`contracts.rs:1122-1180`）が不変。 |

### 8.3 追加発見の条件

| ID | 条件 |
| -- | ---- |
| A・B | 05 の受け入れ条件（05 §9）に従う。本書では二重に確認しない。 |
| C | `{}` への `unwrap_or(json!({}))` が `field_cultivation_climate_data_interactor.rs` に残らない（T3-2 が GREEN）。 |
| D | `entry_schedule.rs` の `stage_rows`、`load_farm`、resolve interactor、`list_by_is_reference` が DB エラーを空リスト・404・422 にしない。`masters_crops.rs:111` に `unwrap_or_default()` が残らない。 |
| E | 項目 3 に含まれる。 |
| F | `cultivation_method` が `None` の作物は、ステージ名の推定に頼らず `eligible: false`（`missing_cultivation_method`）になる。`has_transplant_stage` が存在しない。 |
| G・S | クラス S の各箇所に `unwrap_or*` で Err を捨てる形が残らない。`account.rs` のエクスポートが、失敗時に空の `{}` の 200 を返さない。 |
| H1 | 要件のない作物が `{}` として agrr の調整・候補生成に渡らない。 |
| H2 | 不正な日付文字列と不正 JSON が Err になる。NULL 日付の扱いは R10 の確認結果に従う。 |
| H3 | `area_per_unit` / `revenue_per_area` が NULL の作物で、計画作成が明示的に失敗する。 |
| H4 | show の応答が、緯度・経度が NULL の農場で `null` を返す（list と同じ）。 |
| H7 | `InteractionRuleAgrrFormatBuilderPort` が存在しない。 |
| H9・H10 | Q2・Q4 の回答どおり。 |

---

## 9. 関連課題との依存

`docs/spec-defects/` には本書の改訂時点で 01〜11 と README が存在する（`Glob` で確認）。第 1 版で「未作成・未確認」としていた 05 以降を、存在するファイルとして再確認した。

| 番号 | 題名 | 関係 |
| ---- | ---- | ---- |
| 01 resource-limit-bypass | 資源上限の回避 | 独立。ただし 01 R9 が挙げる `omniauth_session.rs:68-73` は現行ツリーに見つからない（§7.2 R12）。 |
| 02 contact-recaptcha | 問い合わせの reCAPTCHA | 独立。秘密値の `unwrap_or_default()`（`state.rs:97-104`、`contact_message_recaptcha.rs:17`）は、02・04 と突合してから扱う（§2.4）。 |
| 03 api-key-scope-docs | API キースコープの文書 | 03 が本書に残した「`parse_api_key_scopes_json` が不正 JSON を空配列にすることが安全側か」は、空スコープが権限なしであるため、拒否側に倒れる許容として確定（§2.4）。 |
| 04 api-key-query-auth | API キーのクエリ認証 | 独立（本書と扱う箇所は重ならない）。 |
| 05 fail-closed-critical | fail-closed の致命的な違反 | **同系統。実装の前提。** 本書の A は 05-B、本書の B は 05-A と同一箇所で、05 が実施する。05 が本書に引き継いだ箇所は、`field_cultivation_climate_data_interactor.rs:361-362`（C）、`entry_schedule.rs:167-171, :292-299`（項目 2・1）、`plan_allocation_adjust_read_gateway.rs:399-414`（H1・H2）、`field_cultivation_climate.rs:89-92` と `work_record_climate_snapshot.rs:64-78`（E）、`work_record_create_interactor.rs:158-164` / `work_record_update_interactor.rs:82-84`（H9）、`adjust_weather_prediction.rs:118, :142`（H10）、`interaction_rule_agrr_format_builder_port.rs:9`（H7）で、本書がすべて扱う（§2.2、§2.3）。05 と本書は同じ `field_cultivation_climate_data_interactor.rs`、出力ポート、`entry_schedule.rs` の `OptimizeRunner::call` を触るため、05 を先に実装する（`docs/spec-defects/README.md` の着手順）。 |
| 07 frontend-error-contract | フロントのエラー契約 | **依存。** 項目 1・F（`eligible: false` と `reason_parts` の既存形）、項目 3（`climate_data` のエラーは `{success:false, message}` で、HTTP ステータスは `message` の部分一致で決まる: `field_cultivation_climate.rs:102-116`）、項目 4・8（`{"errors":[..]}`）、H1（調整の失敗種別）でエラー応答が変わる。Q1 と H1 のエラー形は、07 の統合方針（`error` / `errors` の単一形式）に合わせる。07 は、05 / 06 が「エラー時の既定値」を規定する場合はそれに従うと記している（07 の関連課題表）。フロントの `climate_data` の消費側（`frontend/src/app/adapters/plans/field-climate-api.gateway.ts:22`）のエラー処理は未確認。 |
| 08 openapi-gaps | OpenAPI の欠落 | **関係あり。** `docs/api/openapi.yaml` に `entry_schedule`・`climate_data`・`weather_reschedule` のパスは存在しない（`grep` で 0 件）。本課題でエラー形を決めた後に、載せるかを 08 で扱う。08 の R8（`masters_crops.rs:111`）は本書の D で扱う。別の OpenAPI ファイルの有無は未確認。 |
| 09 stale-design-docs | 古い設計文書 | 弱い関係。本課題は文書追記を必要としない（§4.3）。`ARCHITECTURE.md` の fail-closed 節の重複（R9）は 09 の範囲かを確認。 |
| 10 authorization-consistency | 認可の一貫性 | 独立。項目 3 の `climate_data` 経路には認可チェックがあるが（`field_cultivation_climate_data_interactor.rs:122-157`）、本計画は触らない。10 が挙げる D2 の空スコープ既定は拒否側であり、本書と競合しない（10 の内容は本改訂でも詳細を読んでいない）。 |
| 11 low-priority-misc | 低優先の雑多 | 依存なし（11 は本書を「依存なし」としている）。項目 5・6・8 は、到達不能・低でも `no-convenience-tech-debt.mdc` により規約違反の残置になるため本課題で扱い、11 へ回さない。 |
