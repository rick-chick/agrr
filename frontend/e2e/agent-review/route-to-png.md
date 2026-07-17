# route-manifest → agent-review/out PNG ファイル名

**この表は `npm run e2e:manifest` で自動生成する。** Agent はユーザーに URL やページ指定を求めず、この表と `e2e/route-manifest.json` を正とする。

## ファイル名規則（`e2e/visual/route-manifest-visual.spec.ts` と同一）

- ベース名: `pattern` が空文字 → `home` / `**` → `not-found` / それ以外は `[a-zA-Z0-9_.-]` 以外を `_` に置換
- 出力: `{ベース名}.{locale}.png`（locale: ja, en, in。in はヒンディー語・インド向け）

## 全ルート一覧

| # | pattern | url (E2E goto) | requiresAuth | ja | en | in |
|---|---------|----------------|--------------|----|----|-----|
| 1 | `(home)` | `/` | no | `home.ja.png` | `home.en.png` | `home.in.png` |
| 2 | `**` | `/__e2e-route-manifest-not-found__` | no | `not-found.ja.png` | `not-found.en.png` | `not-found.in.png` |
| 3 | `about` | `/about` | no | `about.ja.png` | `about.en.png` | `about.in.png` |
| 4 | `contact` | `/contact` | no | `contact.ja.png` | `contact.en.png` | `contact.in.png` |
| 5 | `entry-schedule` | `/entry-schedule` | no | `entry-schedule.ja.png` | `entry-schedule.en.png` | `entry-schedule.in.png` |
| 6 | `entry-schedule/crop/:cropId` | `/entry-schedule/crop/1?farmId=1` | no | `entry-schedule_crop_cropId.ja.png` | `entry-schedule_crop_cropId.en.png` | `entry-schedule_crop_cropId.in.png` |
| 7 | `login` | `/login` | no | `login.ja.png` | `login.en.png` | `login.in.png` |
| 8 | `privacy` | `/privacy` | no | `privacy.ja.png` | `privacy.en.png` | `privacy.in.png` |
| 9 | `public-plans/new` | `/public-plans/new` | no | `public-plans_new.ja.png` | `public-plans_new.en.png` | `public-plans_new.in.png` |
| 10 | `public-plans/optimizing` | `/public-plans/optimizing?planId=1` | no | `public-plans_optimizing.ja.png` | `public-plans_optimizing.en.png` | `public-plans_optimizing.in.png` |
| 11 | `public-plans/results` | `/public-plans/results?planId=1` | no | `public-plans_results.ja.png` | `public-plans_results.en.png` | `public-plans_results.in.png` |
| 12 | `public-plans/select-crop` | `/public-plans/select-crop` | no | `public-plans_select-crop.ja.png` | `public-plans_select-crop.en.png` | `public-plans_select-crop.in.png` |
| 13 | `public-plans/select-farm-size` | `/public-plans/select-farm-size` | no | `public-plans_select-farm-size.ja.png` | `public-plans_select-farm-size.en.png` | `public-plans_select-farm-size.in.png` |
| 14 | `terms` | `/terms` | no | `terms.ja.png` | `terms.en.png` | `terms.in.png` |
| 15 | `agricultural_tasks` | `/agricultural_tasks` | yes | `agricultural_tasks.ja.png` | `agricultural_tasks.en.png` | `agricultural_tasks.in.png` |
| 16 | `agricultural_tasks/:id` | `/agricultural_tasks/1` | yes | `agricultural_tasks_id.ja.png` | `agricultural_tasks_id.en.png` | `agricultural_tasks_id.in.png` |
| 17 | `agricultural_tasks/:id/edit` | `/agricultural_tasks/1/edit` | yes | `agricultural_tasks_id_edit.ja.png` | `agricultural_tasks_id_edit.en.png` | `agricultural_tasks_id_edit.in.png` |
| 18 | `agricultural_tasks/new` | `/agricultural_tasks/new` | yes | `agricultural_tasks_new.ja.png` | `agricultural_tasks_new.en.png` | `agricultural_tasks_new.in.png` |
| 19 | `api-keys` | `/api-keys` | yes | `api-keys.ja.png` | `api-keys.en.png` | `api-keys.in.png` |
| 20 | `crops` | `/crops` | yes | `crops.ja.png` | `crops.en.png` | `crops.in.png` |
| 21 | `crops/:id` | `/crops/1` | yes | `crops_id.ja.png` | `crops_id.en.png` | `crops_id.in.png` |
| 22 | `crops/:id/edit` | `/crops/1/edit` | yes | `crops_id_edit.ja.png` | `crops_id_edit.en.png` | `crops_id_edit.in.png` |
| 23 | `crops/:id/stages` | `/crops/1/stages` | yes | `crops_id_stages.ja.png` | `crops_id_stages.en.png` | `crops_id_stages.in.png` |
| 24 | `crops/:id/stages/:stageId/edit` | `/crops/1/stages/1/edit` | yes | `crops_id_stages_stageId_edit.ja.png` | `crops_id_stages_stageId_edit.en.png` | `crops_id_stages_stageId_edit.in.png` |
| 25 | `crops/:id/task_schedule_blueprints` | `/crops/1/task_schedule_blueprints` | yes | `crops_id_task_schedule_blueprints.ja.png` | `crops_id_task_schedule_blueprints.en.png` | `crops_id_task_schedule_blueprints.in.png` |
| 26 | `crops/new` | `/crops/new` | yes | `crops_new.ja.png` | `crops_new.en.png` | `crops_new.in.png` |
| 27 | `dashboard` | `/dashboard` | yes | `dashboard.ja.png` | `dashboard.en.png` | `dashboard.in.png` |
| 28 | `farms` | `/farms` | yes | `farms.ja.png` | `farms.en.png` | `farms.in.png` |
| 29 | `farms/:id` | `/farms/1` | yes | `farms_id.ja.png` | `farms_id.en.png` | `farms_id.in.png` |
| 30 | `farms/:id/edit` | `/farms/1/edit` | yes | `farms_id_edit.ja.png` | `farms_id_edit.en.png` | `farms_id_edit.in.png` |
| 31 | `farms/new` | `/farms/new` | yes | `farms_new.ja.png` | `farms_new.en.png` | `farms_new.in.png` |
| 32 | `fertilizes` | `/fertilizes` | yes | `fertilizes.ja.png` | `fertilizes.en.png` | `fertilizes.in.png` |
| 33 | `fertilizes/:id` | `/fertilizes/1` | yes | `fertilizes_id.ja.png` | `fertilizes_id.en.png` | `fertilizes_id.in.png` |
| 34 | `fertilizes/:id/edit` | `/fertilizes/1/edit` | yes | `fertilizes_id_edit.ja.png` | `fertilizes_id_edit.en.png` | `fertilizes_id_edit.in.png` |
| 35 | `fertilizes/new` | `/fertilizes/new` | yes | `fertilizes_new.ja.png` | `fertilizes_new.en.png` | `fertilizes_new.in.png` |
| 36 | `interaction_rules` | `/interaction_rules` | yes | `interaction_rules.ja.png` | `interaction_rules.en.png` | `interaction_rules.in.png` |
| 37 | `interaction_rules/:id` | `/interaction_rules/1` | yes | `interaction_rules_id.ja.png` | `interaction_rules_id.en.png` | `interaction_rules_id.in.png` |
| 38 | `interaction_rules/:id/edit` | `/interaction_rules/1/edit` | yes | `interaction_rules_id_edit.ja.png` | `interaction_rules_id_edit.en.png` | `interaction_rules_id_edit.in.png` |
| 39 | `interaction_rules/new` | `/interaction_rules/new` | yes | `interaction_rules_new.ja.png` | `interaction_rules_new.en.png` | `interaction_rules_new.in.png` |
| 40 | `pesticides` | `/pesticides` | yes | `pesticides.ja.png` | `pesticides.en.png` | `pesticides.in.png` |
| 41 | `pesticides/:id` | `/pesticides/1` | yes | `pesticides_id.ja.png` | `pesticides_id.en.png` | `pesticides_id.in.png` |
| 42 | `pesticides/:id/edit` | `/pesticides/1/edit` | yes | `pesticides_id_edit.ja.png` | `pesticides_id_edit.en.png` | `pesticides_id_edit.in.png` |
| 43 | `pesticides/new` | `/pesticides/new` | yes | `pesticides_new.ja.png` | `pesticides_new.en.png` | `pesticides_new.in.png` |
| 44 | `pests` | `/pests` | yes | `pests.ja.png` | `pests.en.png` | `pests.in.png` |
| 45 | `pests/:id` | `/pests/1` | yes | `pests_id.ja.png` | `pests_id.en.png` | `pests_id.in.png` |
| 46 | `pests/:id/edit` | `/pests/1/edit` | yes | `pests_id_edit.ja.png` | `pests_id_edit.en.png` | `pests_id_edit.in.png` |
| 47 | `pests/new` | `/pests/new` | yes | `pests_new.ja.png` | `pests_new.en.png` | `pests_new.in.png` |
| 48 | `plans` | `/plans` | yes | `plans.ja.png` | `plans.en.png` | `plans.in.png` |
| 49 | `plans/:id` | `/plans/1` | yes | `plans_id.ja.png` | `plans_id.en.png` | `plans_id.in.png` |
| 50 | `plans/:id/optimizing` | `/plans/1/optimizing` | yes | `plans_id_optimizing.ja.png` | `plans_id_optimizing.en.png` | `plans_id_optimizing.in.png` |
| 51 | `plans/:id/task_schedule` | `/plans/1/task_schedule` | yes | `plans_id_task_schedule.ja.png` | `plans_id_task_schedule.en.png` | `plans_id_task_schedule.in.png` |
| 52 | `plans/:id/work` | `/plans/1/work` | yes | `plans_id_work.ja.png` | `plans_id_work.en.png` | `plans_id_work.in.png` |
| 53 | `plans/:id/work_records` | `/plans/1/work_records` | yes | `plans_id_work_records.ja.png` | `plans_id_work_records.en.png` | `plans_id_work_records.in.png` |
| 54 | `plans/new` | `/plans/new` | yes | `plans_new.ja.png` | `plans_new.en.png` | `plans_new.in.png` |
| 55 | `work` | `/work` | yes | `work.ja.png` | `work.en.png` | `work.in.png` |

## キャプチャ前提

- `e2e:capture-for-agent` は **`E2E_CAPTURE_DEV_SESSION=1`** で Rails（127.0.0.1:3000）と ng を起動し、globalSetup が **`e2e/.auth/dev-session.json`** を書き出したうえで各 `url` へ **ja / en / in** の順で遷移し `out/{ベース}.{locale}.png` を書き出す（`/api/v1/auth/me` はモックしない）。
- `e2e/resolve-capture-urls.ts` が一覧 API から実在 id を取りマニフェストの placeholder を差し替える。DB が空や API 不全のときは画面が薄い・エラーになり得る。
