# route-manifest → agent-review/out PNG ファイル名

**この表は `npm run e2e:manifest` で自動生成する。** Agent はユーザーに URL やページ指定を求めず、この表と `e2e/route-manifest.json` を正とする。

## ファイル名規則（`e2e/visual/route-manifest-visual.spec.ts` と同一）

- `pattern` が空文字 → `home.png`
- `pattern` が `*`* → `not-found.png`
- それ以外 → `pattern` のうち `[a-zA-Z0-9_.-]` 以外を `_` に置換し、`.png` を付与

## 全ルート一覧


| #   | pattern                         | url (E2E goto)                      | requiresAuth | out/*.png                           |
| --- | ------------------------------- | ----------------------------------- | ------------ | ----------------------------------- |
| 1   | `(home)`                        | `/`                                 | no           | `home.png`                          |
| 2   | `*`*                            | `/__e2e-route-manifest-not-found__` | no           | `not-found.png`                     |
| 3   | `about`                         | `/about`                            | no           | `about.png`                         |
| 4   | `auth/login`                    | `/auth/login`                       | no           | `auth_login.png`                    |
| 5   | `contact`                       | `/contact`                          | no           | `contact.png`                       |
| 6   | `entry-schedule`                | `/entry-schedule`                   | no           | `entry-schedule.png`                |
| 7   | `entry-schedule/crop/:cropId`   | `/entry-schedule/crop/1?farmId=1`   | no           | `entry-schedule_crop_cropId.png`    |
| 8   | `login`                         | `/login`                            | no           | `login.png`                         |
| 9   | `privacy`                       | `/privacy`                          | no           | `privacy.png`                       |
| 10  | `public-plans/new`              | `/public-plans/new`                 | no           | `public-plans_new.png`              |
| 11  | `public-plans/optimizing`       | `/public-plans/optimizing?planId=1` | no           | `public-plans_optimizing.png`       |
| 12  | `public-plans/results`          | `/public-plans/results?planId=1`    | no           | `public-plans_results.png`          |
| 13  | `public-plans/select-crop`      | `/public-plans/select-crop`         | no           | `public-plans_select-crop.png`      |
| 14  | `public-plans/select-farm-size` | `/public-plans/select-farm-size`    | no           | `public-plans_select-farm-size.png` |
| 15  | `terms`                         | `/terms`                            | no           | `terms.png`                         |
| 16  | `agricultural_tasks`            | `/agricultural_tasks`               | yes          | `agricultural_tasks.png`            |
| 17  | `agricultural_tasks/:id`        | `/agricultural_tasks/1`             | yes          | `agricultural_tasks_id.png`         |
| 18  | `agricultural_tasks/:id/edit`   | `/agricultural_tasks/1/edit`        | yes          | `agricultural_tasks_id_edit.png`    |
| 19  | `agricultural_tasks/new`        | `/agricultural_tasks/new`           | yes          | `agricultural_tasks_new.png`        |
| 20  | `api-keys`                      | `/api-keys`                         | yes          | `api-keys.png`                      |
| 21  | `crops`                         | `/crops`                            | yes          | `crops.png`                         |
| 22  | `crops/:id`                     | `/crops/1`                          | yes          | `crops_id.png`                      |
| 23  | `crops/:id/edit`                | `/crops/1/edit`                     | yes          | `crops_id_edit.png`                 |
| 24  | `crops/new`                     | `/crops/new`                        | yes          | `crops_new.png`                     |
| 25  | `dashboard`                     | `/dashboard`                        | yes          | `dashboard.png`                     |
| 26  | `farms`                         | `/farms`                            | yes          | `farms.png`                         |
| 27  | `farms/:id`                     | `/farms/1`                          | yes          | `farms_id.png`                      |
| 28  | `farms/:id/edit`                | `/farms/1/edit`                     | yes          | `farms_id_edit.png`                 |
| 29  | `farms/new`                     | `/farms/new`                        | yes          | `farms_new.png`                     |
| 30  | `fertilizes`                    | `/fertilizes`                       | yes          | `fertilizes.png`                    |
| 31  | `fertilizes/:id`                | `/fertilizes/1`                     | yes          | `fertilizes_id.png`                 |
| 32  | `fertilizes/:id/edit`           | `/fertilizes/1/edit`                | yes          | `fertilizes_id_edit.png`            |
| 33  | `fertilizes/new`                | `/fertilizes/new`                   | yes          | `fertilizes_new.png`                |
| 34  | `interaction_rules`             | `/interaction_rules`                | yes          | `interaction_rules.png`             |
| 35  | `interaction_rules/:id`         | `/interaction_rules/1`              | yes          | `interaction_rules_id.png`          |
| 36  | `interaction_rules/:id/edit`    | `/interaction_rules/1/edit`         | yes          | `interaction_rules_id_edit.png`     |
| 37  | `interaction_rules/new`         | `/interaction_rules/new`            | yes          | `interaction_rules_new.png`         |
| 38  | `pesticides`                    | `/pesticides`                       | yes          | `pesticides.png`                    |
| 39  | `pesticides/:id`                | `/pesticides/1`                     | yes          | `pesticides_id.png`                 |
| 40  | `pesticides/:id/edit`           | `/pesticides/1/edit`                | yes          | `pesticides_id_edit.png`            |
| 41  | `pesticides/new`                | `/pesticides/new`                   | yes          | `pesticides_new.png`                |
| 42  | `pests`                         | `/pests`                            | yes          | `pests.png`                         |
| 43  | `pests/:id`                     | `/pests/1`                          | yes          | `pests_id.png`                      |
| 44  | `pests/:id/edit`                | `/pests/1/edit`                     | yes          | `pests_id_edit.png`                 |
| 45  | `pests/new`                     | `/pests/new`                        | yes          | `pests_new.png`                     |
| 46  | `plans`                         | `/plans`                            | yes          | `plans.png`                         |
| 47  | `plans/:id`                     | `/plans/1`                          | yes          | `plans_id.png`                      |
| 48  | `plans/:id/optimizing`          | `/plans/1/optimizing`               | yes          | `plans_id_optimizing.png`           |
| 49  | `plans/:id/task_schedule`       | `/plans/1/task_schedule`            | yes          | `plans_id_task_schedule.png`        |
| 50  | `plans/new`                     | `/plans/new`                        | yes          | `plans_new.png`                     |
| 51  | `plans/select-crop`             | `/plans/select-crop`                | yes          | `plans_select-crop.png`             |
| 52  | `weather`                       | `/weather`                          | yes          | `weather.png`                       |


## キャプチャ前提

- `e2e:capture-for-agent` は **storage state 不要**。Playwright が `GET /api/v1/auth/me` を成功レスポンスに置き換え、authGuard 通過後に各 `url` へ遷移して `out/*.png` を書き出す。
- 一覧・詳細はバックエンド未取得時もレイアウトレビュー用に撮影される。実データ・本番同等 UI が必要なら別途 API 起動や `e2e/.auth` を用いる。

