# ビジュアルレビュー結果（Agent キャプチャ）

- **レビュー日**: 2026-05-04（キャプチャ実行に基づく）
- **対象**: `route-to-png.md` 表 #1–#52（全ルート）
- **キャプチャ条件**: `npm run e2e:capture-for-agent` … `GET /api/v1/auth/me` のみモック。**Rails/API は未起動のため** `127.0.0.1:4200/api/...` へのリクエストは多くが 404。レイアウトレビューと**画面状態の記録**が主目的。
- **スキル**: `frontend-agent-visual-review`

## サマリ表（1 画面 1 行）


| #   | pattern                         | PNG                                                    | 結果  | 指摘                                                                                                  |
| --- | ------------------------------- | ------------------------------------------------------ | --- | --------------------------------------------------------------------------------------------------- |
| 1   | `(home)`                        | `home.png`                                             | OK  | なし（ナビに「E2E Agent Review」表示はキャプチャ前提として許容）                                                            |
| 2   | `*`*                            | `not-found.png`                                        | OK  | なし（意図した 404 ページ）                                                                                    |
| 3   | `about`                         | `about.png`                                            | 要確認 | `pages.about.operator.contact` 等、翻訳キーがそのまま表示                                                        |
| 4   | `auth/login`                    | `auth_login.png`                                       | 要確認 | `login.title` / `login.description` が未解決。ログイン画面なのにヘッダーにログアウトあり（状態のねじれ）                              |
| 5   | `contact`                       | `contact.png`                                          | OK  | なし                                                                                                  |
| 6   | `entry-schedule`                | `entry-schedule.png`                                   | 要確認 | 「読み込みに失敗しました」（API 未到達）                                                                              |
| 7   | `entry-schedule/crop/:cropId`   | `entry-schedule_crop_cropId.png`                       | 要確認 | 同上                                                                                                  |
| 8   | `login`                         | `login.png`                                            | 要確認 | #4 と同様（i18n 未解決・認証 UI のねじれ）                                                                         |
| 9   | `privacy`                       | `privacy.png`                                          | 要確認 | `pages.privacy.intro` 等、複数プレースホルダ                                                                   |
| 10  | `public-plans/new`              | `public-plans_new.png`                                 | 要確認 | `public_plans/farms` の raw HTTP 404 メッセージ表示                                                         |
| 11  | `public-plans/optimizing`       | `public-plans_optimizing.png`                          | 注意  | 最適化準備 UI は表示。「0種類の作物」はデータなし時の見え方として許容だが要確認                                                          |
| 12  | `public-plans/results`          | `public-plans_results.png`                             | 要確認 | `cultivation_plans/1/data` の 404 が二重バナーで表示                                                          |
| 13  | `public-plans/select-crop`      | `public-plans_select-crop.png`                         | 要確認 | #10 と同様（farms API 404）                                                                              |
| 14  | `public-plans/select-farm-size` | `public-plans_select-farm-size.png`                    | 要確認 | 同上                                                                                                  |
| 15  | `terms`                         | `terms.png`                                            | 要確認 | `pages.terms.article10.content` が未解決                                                                |
| 16  | `agricultural_tasks`            | `agricultural_tasks.png`                               | 要確認 | masters API 404、一覧エリア空                                                                              |
| 17  | `agricultural_tasks/:id`        | `agricultural_tasks_id.png`                            | 要確認 | 404、本文ほぼ空                                                                                           |
| 18  | `agricultural_tasks/:id/edit`   | `agricultural_tasks_id_edit.png`                       | 要確認 | 404・タイトル `%{name}` 露出・地域ドロップダウンが他項目より極端に狭い                                                          |
| 19  | `agricultural_tasks/new`        | `agricultural_tasks_new.png`                           | 注意  | レイアウトは妥当。地域セレクト幅が狭い（他マスタ新規フォームと共通傾向）                                                                |
| 20  | `api-keys`                      | `api-keys.png`                                         | 注意  | 「APIキーを生成」が他のプライマリボタンと比べ小さめ・コントラスト弱めに見える                                                            |
| 21  | `crops`                         | `crops.png`（一括 E2E） / `**crops.logged-in.png`（ログイン後）** | 注意  | **一括キャプチャ**は API 未到達で 404。**ログイン解決後**（下記「作物一覧」参照）: グリッド・編集/削除ボタン・アクセントは一貫。データ面で日英混在、フッター年表記の差は別途要確認 |
| 22  | `crops/:id`                     | `crops_id.png`                                         | 要確認 | 404・本文空                                                                                             |
| 23  | `crops/:id/edit`                | `crops_id_edit.png`                                    | 要確認 | 404・`%{name}`・地域狭幅                                                                                  |
| 24  | `crops/new`                     | `crops_new.png`                                        | 注意  | #19 と同様（地域セレクト幅）                                                                                    |
| 25  | `dashboard`                     | `dashboard.png`                                        | OK  | なし（ホーム相当の英語 UI・#1 と同種）                                                                              |
| 26  | `farms`                         | `farms.png`                                            | 要確認 | farms 一覧 API 404                                                                                    |
| 27  | `farms/:id`                     | `farms_id.png`                                         | 要確認 | 404・本文空                                                                                             |
| 28  | `farms/:id/edit`                | `farms_id_edit.png`                                    | 要確認 | 404。地図・フォーム枠は見えるがデータ未取得                                                                             |
| 29  | `farms/new`                     | `farms_new.png`                                        | OK  | なし（地図・既定座標あり）                                                                                       |
| 30  | `fertilizes`                    | `fertilizes.png`                                       | 要確認 | 404 バナーありつつ空状態メッセージも表示（状態のミスマッチ）                                                                    |
| 31  | `fertilizes/:id`                | `fertilizes_id.png`                                    | 要確認 | 404                                                                                                 |
| 32  | `fertilizes/:id/edit`           | `fertilizes_id_edit.png`                               | 要確認 | 404・`%{name}`                                                                                       |
| 33  | `fertilizes/new`                | `fertilizes_new.png`                                   | 注意  | 地域セレクト幅                                                                                             |
| 34  | `interaction_rules`             | `interaction_rules.png`                                | 要確認 | 404                                                                                                 |
| 35  | `interaction_rules/:id`         | `interaction_rules_id.png`                             | 要確認 | 404                                                                                                 |
| 36  | `interaction_rules/:id/edit`    | `interaction_rules_id_edit.png`                        | 要確認 | 404・ラベル `interaction_rules.form.is_directional_label` 露出                                            |
| 37  | `interaction_rules/new`         | `interaction_rules_new.png`                            | 要確認 | ルール種類に raw 値 `continuous_cultivation`・同一 i18n キー露出                                                  |
| 38  | `pesticides`                    | `pesticides.png`                                       | 要確認 | 404                                                                                                 |
| 39  | `pesticides/:id`                | `pesticides_id.png`                                    | 要確認 | 404                                                                                                 |
| 40  | `pesticides/:id/edit`           | `pesticides_id_edit.png`                               | 要確認 | 404・見出しやラベルが英語混在（Edit Pesticide / Name）・地域ネイティブ select                                              |
| 41  | `pesticides/new`                | `pesticides_new.png`                                   | 注意  | 英語タイトル「Create Pesticide」・地域ネイティブ select のみ他と不揃い                                                     |
| 42  | `pests`                         | `pests.png`                                            | 要確認 | 404                                                                                                 |
| 43  | `pests/:id`                     | `pests_id.png`                                         | 要確認 | 404                                                                                                 |
| 44  | `pests/:id/edit`                | `pests_id_edit.png`                                    | 要確認 | 404・`%{name}`・地域狭幅                                                                                  |
| 45  | `pests/new`                     | `pests_new.png`                                        | 注意  | 地域セレクト・フッターリンクのコントラスト                                                                               |
| 46  | `plans`                         | `plans.png`                                            | 要確認 | 404 がグローバルバナー＋カード内の二重表示                                                                             |
| 47  | `plans/:id`                     | `plans_id.png`                                         | 要確認 | plans/1 が 404                                                                                       |
| 48  | `plans/:id/optimizing`          | `plans_id_optimizing.png`                              | 注意  | 英語見出し「Optimizing」「Back to plan」・Progress 0% のみ（API なしでは妥当）                                          |
| 49  | `plans/:id/task_schedule`       | `plans_id_task_schedule.png`                           | 要確認 | task_schedule 404 が raw 表示                                                                          |
| 50  | `plans/new`                     | `plans_new.png`                                        | 要確認 | farms 404 で農場選択 UI 未表示                                                                              |
| 51  | `plans/select-crop`             | `plans_select-crop.png`                                | 注意  | 「農場IDが指定されていません」（URL 前提の冷スタート。仕様どおりだが一覧性は要確認）                                                       |
| 52  | `weather`                       | `weather.png`                                          | 注意  | 「Weather」英語見出し・気温チャート領域が空（データ未取得）                                                                   |


## 集計（参考）


| 結果  | 件数  |
| --- | --- |
| OK  | 6   |
| 注意  | 12  |
| 要確認 | 34  |


## 作物一覧（`crops`）— ログイン後キャプチャ（コード変更なし）

一括の `e2e:capture-for-agent` は多くの画面で API が 127.0.0.1:4200 に向き 404 になる。**本番に近い一覧 UI を 1 画面だけ**見るには、Rails（development）とフロントが生きた上で **セッション付き**で `/crops` を開く。

- **API 向き先**: `getApiBaseUrl()` は `**localhost:4200`** のときだけ `http://localhost:3000` を使う。Playwright 既定の `127.0.0.1:4200` だけだと API が別ホストにならず 404 になりやすい。
- **モックログイン**（OAuth 不要・development / test のみ）: `**/ja/` を付けない**。

```text
http://localhost:3000/auth/test/mock_login_as/developer?return_to=http%3A%2F%2Flocalhost%3A4200%2Fcrops
```

上記をブラウザで開き、`localhost:4200/crops` へ戻った状態でスクリーンショットする。

- **今回の成果物**: `e2e/agent-review/out/crops.logged-in.png`（一覧カード・編集/削除・ヘッダ「開発者」表示を確認。作物名の日英混在・フッター年次表記はデータ/文言の別課題として切り分け可能）

## 指摘の詳細（横断）

1. **API 未到達（404）**
  本キャプチャでは `/me` 以外は未モックのため、マスタ・計画・公開計画の多くで **生の Http failure メッセージ**または空画面となる。本番同等の見た目レビューには **API モック追加**または **Rails 起動＋シード**が必要。
2. **i18n 未解決**
  ログイン／プライバシー／利用規約／about／連作ルール新規・編集で **キー文字列や `%{name}`** が画面上に残っている。CSS 監査とは独立した **製品バグ**として扱うのがよい。
3. **言語・コンポーネントの揺れ**
  農薬まわりの英語ラベル、計画最適化の英語、天気の「Weather」など **日英混在**。地域フィールドが **ネイティブ select で狭い**画面が複数。
4. **ヘッダー「E2E Agent Review」**
  モックユーザ名による挙動。本番スクリーンショットとは差異がある点に注意。

---

**総評（表の後出し）**: 今回の 52 枚は「ルート到達＋撮影」の意味では揃ったが、**未モック API により「コンテンツが揃った OK」画面は少数**。ビジュアルレビュー成果物としては **環境要因と製品要因を分けた上で、上表の「要確認」をチケット化する**のが実務的である。CSS トークン監査は `npm run audit:css-tokens` を正とする。