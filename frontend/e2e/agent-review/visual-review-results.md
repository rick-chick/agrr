# Agent ビジュアルレビュー結果

## メタ

- **レビュー日**: 2026-05-09（ローカル実行時刻。UTC 換算は環境依存のため未記録）
- **対象行**: `route-to-png.md` 表の **#1–52**（全ルート）
- **キャプチャ**: `cd frontend && npm run e2e:capture-for-agent`（`E2E_CAPTURE_DEV_SESSION=1`）。Playwright が Rails development（`127.0.0.1:3000`）と `ng serve`（`127.0.0.1:4200`）を起動し、`globalSetup` が **AuthTestController モックログイン**で `e2e/.auth/dev-session.json` を生成。`**/api/v1/auth/me` はモックしていない**（スキル記載どおり）。`e2e/resolve-capture-urls.ts` で一覧 API 由来の実 ID に URL を差し替え。**検証**: `verify-capture-complete.mjs` で **52 PNG** 一致を確認済み。
- **前提の一言**: development DB・API 応答に依存。空データや遅延で「読み込み中」や空チャートになり得る。CSS トークンの機械監査は `**npm run audit:css-tokens`** を正とし、本レビューでは PNG のレイアウト・重なり・包含のみ扱う。

## サマリ表


| #   | pattern                         | PNG                                 | 結果  | 指摘                                                               |
| --- | ------------------------------- | ----------------------------------- | --- | ---------------------------------------------------------------- |
| 1   | `(home)`                        | `home.png`                          | OK  | なし                                                               |
| 2   | `**`                            | `not-found.png`                     | OK  | なし                                                               |
| 3   | `about`                         | `about.png`                         | OK  | なし                                                               |
| 4   | `auth/login`                    | `auth_login.png`                    | OK  | なし                                                               |
| 5   | `contact`                       | `contact.png`                       | OK  | なし                                                               |
| 6   | `entry-schedule`                | `entry-schedule.png`                | OK  | なし                                                               |
| 7   | `entry-schedule/crop/:cropId`   | `entry-schedule_crop_cropId.png`    | OK  | なし                                                               |
| 8   | `login`                         | `login.png`                         | OK  | なし                                                               |
| 9   | `privacy`                       | `privacy.png`                       | OK  | なし                                                               |
| 10  | `public-plans/new`              | `public-plans_new.png`              | OK  | なし                                                               |
| 11  | `public-plans/optimizing`       | `public-plans_optimizing.png`       | OK  | なし                                                               |
| 12  | `public-plans/results`          | `public-plans_results.png`          | OK  | なし                                                               |
| 13  | `public-plans/select-crop`      | `public-plans_select-crop.png`      | OK  | なし                                                               |
| 14  | `public-plans/select-farm-size` | `public-plans_select-farm-size.png` | OK  | なし                                                               |
| 15  | `terms`                         | `terms.png`                         | OK  | なし                                                               |
| 16  | `agricultural_tasks`            | `agricultural_tasks.png`            | 注意  | `.section-card` 下端がカード列を横切り、カードが枠外にはみ出して見える                      |
| 17  | `agricultural_tasks/:id`        | `agricultural_tasks_id.png`         | OK  | なし                                                               |
| 18  | `agricultural_tasks/:id/edit`   | `agricultural_tasks_id_edit.png`    | OK  | なし                                                               |
| 19  | `agricultural_tasks/new`        | `agricultural_tasks_new.png`        | OK  | なし                                                               |
| 20  | `api-keys`                      | `api-keys.png`                      | 注意  | 本文左寄せで右に大きな余白。コード例の薄いグレー文字の視認性が低い可能性                             |
| 21  | `crops`                         | `crops.png`                         | OK  | なし                                                               |
| 22  | `crops/:id`                     | `crops_id.png`                      | OK  | なし                                                               |
| 23  | `crops/:id/edit`                | `crops_id_edit.png`                 | OK  | なし                                                               |
| 24  | `crops/new`                     | `crops_new.png`                     | OK  | なし                                                               |
| 25  | `dashboard`                     | `dashboard.png`                     | OK  | なし                                                               |
| 26  | `farms`                         | `farms.png`                         | 注意  | 3 列カード内で「編集」「削除」の折返し・縦位置がカード間で不揃い、行の下辺がそろわない                     |
| 27  | `farms/:id`                     | `farms_id.png`                      | OK  | なし                                                               |
| 28  | `farms/:id/edit`                | `farms_id_edit.png`                 | OK  | なし                                                               |
| 29  | `farms/new`                     | `farms_new.png`                     | OK  | なし                                                               |
| 30  | `fertilizes`                    | `fertilizes.png`                    | 注意  | 白い `.section-card` の下辺がカード中央付近を横切り、カードが包含枠からはみ出して見える             |
| 31  | `fertilizes/:id`                | `fertilizes_id.png`                 | OK  | なし                                                               |
| 32  | `fertilizes/:id/edit`           | `fertilizes_id_edit.png`            | OK  | なし                                                               |
| 33  | `fertilizes/new`                | `fertilizes_new.png`                | OK  | なし                                                               |
| 34  | `interaction_rules`             | `interaction_rules.png`             | 注意  | 一覧カードが親コンテナの下境界をまたぎ、下半分が枠外に出ている                                  |
| 35  | `interaction_rules/:id`         | `interaction_rules_id.png`          | OK  | なし                                                               |
| 36  | `interaction_rules/:id/edit`    | `interaction_rules_id_edit.png`     | OK  | なし                                                               |
| 37  | `interaction_rules/new`         | `interaction_rules_new.png`         | OK  | なし                                                               |
| 38  | `pesticides`                    | `pesticides.png`                    | 要確認 | 内側リスト枠が上にずれ「農薬を作成」ボタンと重なる。意図しない `position` / `margin` / スタックの可能性 |
| 39  | `pesticides/:id`                | `pesticides_id.png`                 | OK  | なし                                                               |
| 40  | `pesticides/:id/edit`           | `pesticides_id_edit.png`            | OK  | なし                                                               |
| 41  | `pesticides/new`                | `pesticides_new.png`                | OK  | なし                                                               |
| 42  | `pests`                         | `pests.png`                         | 注意  | `.section-card` 下端がカードを切断するように見え、包含が崩れている                        |
| 43  | `pests/:id`                     | `pests_id.png`                      | OK  | なし                                                               |
| 44  | `pests/:id/edit`                | `pests_id_edit.png`                 | OK  | なし                                                               |
| 45  | `pests/new`                     | `pests_new.png`                     | OK  | なし                                                               |
| 46  | `plans`                         | `plans.png`                         | 要確認 | 計画カードが横方向に重なり左カードは親枠より左へはみ出す。計画一覧の前回 CSS 修正が画面上では未解消             |
| 47  | `plans/:id`                     | `plans_id.png`                      | 注意  | ガントバー内テキスト省略と削除アイコンの距離が詰まり、視認性・タップ領域の確認余地                        |
| 48  | `plans/:id/optimizing`          | `plans_id_optimizing.png`           | 注意  | コンテンツが薄い画面でフッター手前に大きな空白（`min-height: 100vh` 系と短コンテンツの相互作用の可能性）   |
| 49  | `plans/:id/task_schedule`       | `plans_id_task_schedule.png`        | 注意  | 同上、短いカード＋大きな下余白でフッターが画面中段付近                                      |
| 50  | `plans/new`                     | `plans_new.png`                     | 注意  | 「農場を選択」ラベルとセレクトが横に詰まり重なって読みにくい                                   |
| 51  | `plans/select-crop`             | `plans_select-crop.png`             | OK  | なし                                                               |
| 52  | `weather`                       | `weather.png`                       | 注意  | 「気温チャート」枠内が空（データ未取得・コンポーネント未描画の別因もあり得るが、枠だけが目立つ）                 |


## 集計（任意）


| 結果  | 件数  |
| --- | --- |
| OK  | 39  |
| 注意  | 11  |
| 要確認 | 2   |


## 指摘の詳細（注意・要確認のみ）

### #38 `pesticides.png`（要確認）

上部の主ボタン「農薬を作成」と、その下のリスト用の白枠が**縦方向に食い違い**、枠線がボタン領域にかかる。ヘッダーアクション＋`.card-list` のレイアウト順（flex/grid/gap）または**絶対配置・負マージ**の有無をコード側で確認する価値が高い。

### #46 `plans.png`（要確認）

計画一覧の**2 カードが互いに重なり**、左カードは**外枠より左にはみ出す**。`align-self: stretch` / `:host` 対応後もキャプチャ上は**未解消**のため、`.page-main` 以外（例: `.card-list` グリッド、`article.item-card` の `flex`/`min-height`、親の `overflow`）を追加調査する必要がある。

### マスタ系一覧の共通傾向（注意行 #16, #30, #34, #42 など）

「新規追加」ボタン＋`.card-list` を持つ画面で、**外側 `.section-card` の高さがカード列を包んでおらず**、境界線がカードの途中を横切る見え方が複数画面で共通。`_master-layout.css` の `.section-card` と `.card-list` / `.section-card__header-actions` の**フロー内配置**（高さの伝播、`min-height: 100%` 等）を横断的に見直すとよい。

---

## 総評（表の後）

キャプチャは **52 枚すべて verify 済み**の集合に基づく。公開ページ・詳細/編集の多くは **OK**。一方、**マスタ一覧（カードグリッド）と計画一覧・農薬一覧**では、**親枠とカード列の包含関係**に明確な破綻があり、ユーザー報告の「CSS 上だめだった」は `**plans.png` で再現**している。次の実装イテレーションでは、計画一覧に限らず `**.page-main > .section-card` 内のヘッダー行＋グリッド**のスタックを統合的に直すことを推奨する。