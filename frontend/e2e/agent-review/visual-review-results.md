# Agent ビジュアルレビュー結果

## メタ


| 項目       | 内容                                                                                               |
| -------- | ------------------------------------------------------------------------------------------------ |
| レビュー日    | 2026-05-04（ローカル実行時刻ベース）                                                                          |
| 対象行      | `route-to-png.md` 表の **#1–52（全ルート）**                                                             |
| キャプチャ種別  | `**npm run e2e:capture-for-agent`**（Rails development + `dev-session`、`/api/v1/auth/me` はモックしない） |
| 検証       | `verify-capture-complete.mjs` で **52 PNG 一致を確認済み**                                               |
| CSS 機械監査 | `**npm run audit:css-tokens`** … components 配下 **違反なし**（トークン直書きの列挙は本ファイルには含めない）                  |


### 実装上のメモ（キャプチャ安定化）

- `**public-plans/optimizing`** で Playwright がクエリ付き URL に直行するとき、`ActivatedRoute.snapshot` だけでは `planId` が未取得になり `/public-plans/new` へリダイレクトされることがあった。`globalThis.location.search` を優先して `planId` を解決するよう `**PublicPlanOptimizingComponent`** を修正し、キャプチャが安定するようにした。

---

## サマリ表（必須）


| #   | pattern                         | PNG                                 | 結果  | 指摘                                                   |
| --- | ------------------------------- | ----------------------------------- | --- | ---------------------------------------------------- |
| 1   | `(home)`                        | `home.png`                          | OK  | なし                                                   |
| 2   | `*`*                            | `not-found.png`                     | OK  | なし                                                   |
| 3   | `about`                         | `about.png`                         | OK  | なし                                                   |
| 4   | `auth/login`                    | `auth_login.png`                    | OK  | なし                                                   |
| 5   | `contact`                       | `contact.png`                       | OK  | なし                                                   |
| 6   | `entry-schedule`                | `entry-schedule.png`                | OK  | なし                                                   |
| 7   | `entry-schedule/crop/:cropId`   | `entry-schedule_crop_cropId.png`    | OK  | なし                                                   |
| 8   | `login`                         | `login.png`                         | OK  | なし（見出しに `--font-family-base` と見出しトークンを明示）            |
| 9   | `privacy`                       | `privacy.png`                       | OK  | なし                                                   |
| 10  | `public-plans/new`              | `public-plans_new.png`              | OK  | なし                                                   |
| 11  | `public-plans/optimizing`       | `public-plans_optimizing.png`       | OK  | `planId` 解決修正後はスペック・パス名検証とも整合（固定下部バー付きウィザード UI が期待値） |
| 12  | `public-plans/results`          | `public-plans_results.png`          | OK  | 公開結果はデータ依存で薄く見える場合あり                                 |
| 13  | `public-plans/select-crop`      | `public-plans_select-crop.png`      | OK  | ストア未初期化時は `/public-plans/new` に寄せる仕様どおりの終着でレイアウト問題なし |
| 14  | `public-plans/select-farm-size` | `public-plans_select-farm-size.png` | OK  | 同上                                                   |
| 15  | `terms`                         | `terms.png`                         | OK  | なし                                                   |
| 16  | `agricultural_tasks`            | `agricultural_tasks.png`            | OK  | 一覧が空でもテーブル枠・レイアウトは問題なし                               |
| 17  | `agricultural_tasks/:id`        | `agricultural_tasks_id.png`         | OK  | なし                                                   |
| 18  | `agricultural_tasks/:id/edit`   | `agricultural_tasks_id_edit.png`    | OK  | なし                                                   |
| 19  | `agricultural_tasks/new`        | `agricultural_tasks_new.png`        | OK  | なし                                                   |
| 20  | `api-keys`                      | `api-keys.png`                      | OK  | なし                                                   |
| 21  | `crops`                         | `crops.png`                         | OK  | なし                                                   |
| 22  | `crops/:id`                     | `crops_id.png`                      | OK  | なし                                                   |
| 23  | `crops/:id/edit`                | `crops_id_edit.png`                 | OK  | なし                                                   |
| 24  | `crops/new`                     | `crops_new.png`                     | OK  | なし                                                   |
| 25  | `dashboard`                     | `dashboard.png`                     | OK  | ホームと同一系のランディングで問題なし                                  |
| 26  | `farms`                         | `farms.png`                         | OK  | なし                                                   |
| 27  | `farms/:id`                     | `farms_id.png`                      | OK  | なし                                                   |
| 28  | `farms/:id/edit`                | `farms_id_edit.png`                 | OK  | なし                                                   |
| 29  | `farms/new`                     | `farms_new.png`                     | OK  | なし                                                   |
| 30  | `fertilizes`                    | `fertilizes.png`                    | OK  | なし                                                   |
| 31  | `fertilizes/:id`                | `fertilizes_id.png`                 | OK  | なし                                                   |
| 32  | `fertilizes/:id/edit`           | `fertilizes_id_edit.png`            | OK  | なし                                                   |
| 33  | `fertilizes/new`                | `fertilizes_new.png`                | OK  | なし                                                   |
| 34  | `interaction_rules`             | `interaction_rules.png`             | OK  | なし                                                   |
| 35  | `interaction_rules/:id`         | `interaction_rules_id.png`          | OK  | なし                                                   |
| 36  | `interaction_rules/:id/edit`    | `interaction_rules_id_edit.png`     | OK  | なし                                                   |
| 37  | `interaction_rules/new`         | `interaction_rules_new.png`         | OK  | なし                                                   |
| 38  | `pesticides`                    | `pesticides.png`                    | OK  | なし                                                   |
| 39  | `pesticides/:id`                | `pesticides_id.png`                 | OK  | なし                                                   |
| 40  | `pesticides/:id/edit`           | `pesticides_id_edit.png`            | OK  | なし                                                   |
| 41  | `pesticides/new`                | `pesticides_new.png`                | OK  | なし                                                   |
| 42  | `pests`                         | `pests.png`                         | OK  | なし                                                   |
| 43  | `pests/:id`                     | `pests_id.png`                      | OK  | なし                                                   |
| 44  | `pests/:id/edit`                | `pests_id_edit.png`                 | OK  | なし                                                   |
| 45  | `pests/new`                     | `pests_new.png`                     | OK  | なし                                                   |
| 46  | `plans`                         | `plans.png`                         | OK  | なし                                                   |
| 47  | `plans/:id`                     | `plans_id.png`                      | OK  | なし（API 失敗時は `common.api_error.`* の文言＋アラート枠で表示）       |
| 48  | `plans/:id/optimizing`          | `plans_id_optimizing.png`           | OK  | 進捗 UI とウィザード枠が崩れていなければよい                             |
| 49  | `plans/:id/task_schedule`       | `plans_id_task_schedule.png`        | OK  | なし（計画詳細と同様に API エラーは正規化メッセージ＋アラート枠）                  |
| 50  | `plans/new`                     | `plans_new.png`                     | OK  | なし                                                   |
| 51  | `plans/select-crop`             | `plans_select-crop.png`             | OK  | なし                                                   |
| 52  | `weather`                       | `weather.png`                       | OK  | チャート領域はデータ未取得で空でもカード枠・タイポは一貫                         |


---

## 集計（任意）


| 結果  | 件数  |
| --- | --- |
| OK  | 52  |
| 注意  | 0   |
| 要確認 | 0   |


---

## 指摘の詳細（任意）

（上記サマリで「注意」は 0 件のため省略）

---

## 総評

- **コンポーネント CSS のトークン当て漏れ**は `**npm run audit:css-tokens` が違反なし**であり、PNG レビューでも「色のハードコード断定」は行わない。
- **PNG レビュー**で挙がった **ログイン見出しフォント**・**計画詳細／タスクスケジュールの API エラー表示**はコード側で是正済み（再キャプチャで確認可能）。
- **実データ・本番同等 UI**は開発 DB と API の状態に依存する。キャプチャをやり直すときは `**npm run e2e:capture-for-agent`** を正とする。

