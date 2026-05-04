# ビジュアルレビュー結果（Agent キャプチャ）

- **レビュー日**: 2026-05-04（`e2e/agent-review/out/*.png` を **with-api 再キャプチャ後**に確認。環境再起動後 `npm run e2e:capture-for-agent:with-api` は **52/52 通過・verify OK**）
- **対象**: `route-to-png.md` 表 #1–#52（全ルート）
- **キャプチャ条件**: `npm run e2e:capture-for-agent:with-api`（`E2E_CAPTURE_DEV_SESSION=1`）。Rails development を `E2E_API_ORIGIN`（既定 `http://127.0.0.1:3000`）へ向け、`e2e/.auth/dev-session.json` でセッション付きキャプチャ。`**e2e/resolve-capture-urls.ts`** が一覧 API から実在 id を取得し、マニフェストの placeholder `1` を URL 組み立てで差し替える（多桁 id での誤置換はしない）。
- **スキル**: `frontend-agent-visual-review`
- **フォローアップ実装（リポジトリ）**: 静的ページ・ログインの i18n 整合、`resolve-capture-urls` の farm 整合 cropId、`GET /api/v1/plans/:id/task_schedule` の追加、レビュー注意項目（#6/#20/#26/#37–41/#48/#52）の一部を反映済み。再キャプチャで OK／要確認が更新される想定。

## サマリ表（1 画面 1 行）


| #   | pattern                         | PNG                                 | 結果  | 指摘                                                                           |
| --- | ------------------------------- | ----------------------------------- | --- | ---------------------------------------------------------------------------- |
| 1   | `(home)`                        | `home.png`                          | OK  | セッションありのためヘッダに「開発者」「ログアウト」表示（キャプチャ前提として許容）                                   |
| 2   | `*`*                            | `not-found.png`                     | OK  | 意図した 404 ページ                                                                 |
| 3   | `about`                         | `about.png`                         | 要確認 | `pages.about.operator.contact` / `pages.about.operator.ads_notice` 等キー露出     |
| 4   | `auth/login`                    | `auth_login.png`                    | 要確認 | `login.title` / `login.description` 未解決。ヘッダは「確認中…」寄り                         |
| 5   | `contact`                       | `contact.png`                       | OK  | フォーム・注意事項まで表示。ヘッダ「確認中…」は検討余地あり                                               |
| 6   | `entry-schedule`                | `entry-schedule.png`                | 注意  | **一覧前の初期状態**（地域未選択・「表示」無効）。説明文は「農場」とのねじれ。スケジュール表自体は未表示が手順上想定内                |
| 7   | `entry-schedule/crop/:cropId`   | `entry-schedule_crop_cropId.png`    | 要確認 | **読み込み失敗**（赤帯＋「再試行」）。スピナーではない。作物目安 API／`farmId`・`cropId` の整合を別途確認            |
| 8   | `login`                         | `login.png`                         | 要確認 | 実質 #4 と同種（キー露出＋ログイン画面なのにログアウト表示のねじれ）                                         |
| 9   | `privacy`                       | `privacy.png`                       | 要確認 | `pages.privacy.intro` ・ section4/5/8 など複数キー露出                                |
| 10  | `public-plans/new`              | `public-plans_new.png`              | OK  | ステッパー＋**都道府県（利用可能な農場）グリッド**まで表示（`.loading-state` 消滅待ち後のキャプチャ）                |
| 11  | `public-plans/optimizing`       | `public-plans_optimizing.png`       | 注意  | 「最適化を準備しています…」「0種類の作物」— 進行 UI はあるがデータ・タイマーは環境依存                              |
| 12  | `public-plans/results`          | `public-plans_results.png`          | OK  | 公開プラン id 試行で 200 となった例。**ガント**（例: ナス）表示まで到達。下段は選択待ち文言                        |
| 13  | `public-plans/select-crop`      | `public-plans_select-crop.png`      | OK  | 冷スタートで `/public-plans/new` へ寄せたうえで **#10 と同様にグリッド表示**（PNG は new と同一系）        |
| 14  | `public-plans/select-farm-size` | `public-plans_select-farm-size.png` | OK  | #13 と同様                                                                      |
| 15  | `terms`                         | `terms.png`                         | 要確認 | 第10条が `pages.terms.article10.content` のまま                                    |
| 16  | `agricultural_tasks`            | `agricultural_tasks.png`            | OK  | **作業一覧**にレコード表示・編集/削除ボタンまで描画（スナップショット前の `master-loading` 待ち後）                |
| 17  | `agricultural_tasks/:id`        | `agricultural_tasks_id.png`         | OK  | **農作業詳細**（例: 作業名 ddd）まで表示。読み込み中でない                                           |
| 18  | `agricultural_tasks/:id/edit`   | `agricultural_tasks_id_edit.png`    | OK  | **見出し `dddを編集`**・フォーム充填済み。i18n `{{name}}` 補間と待機ともに問題なし                       |
| 19  | `agricultural_tasks/new`        | `agricultural_tasks_new.png`        | OK  | 新規フォーム表示。地域セレクト幅は他マスタと同傾向                                                    |
| 20  | `api-keys`                      | `api-keys.png`                      | 注意  | 機能は問題なし。「APIキーを再生成」の視認性（コントラスト・サイズ）は他プライマリと比べ弱め                              |
| 21  | `crops`                         | `crops.png`                         | OK  | 一覧・カード・編集/削除まで表示（日英混在はデータ／i18n 別課題）                                          |
| 22  | `crops/:id`                     | `crops_id.png`                      | OK  | **トマト詳細**・生育ステージまで表示（with-api＋待機後）                                           |
| 23  | `crops/:id/edit`                | `crops_id_edit.png`                 | OK  | **「トマトを編集」**・フォーム・生育ステージ編集 UI まで表示                                           |
| 24  | `crops/new`                     | `crops_new.png`                     | OK  | 新規フォーム良好                                                                     |
| 25  | `dashboard`                     | `dashboard.png`                     | OK  | ホーム相当で #1 と同種                                                                |
| 26  | `farms`                         | `farms.png`                         | 注意  | **農場一覧**は大量データまで表示。長い名前でカード高さ不揃い・編集/削除の折返し、先頭カードに欠損っぽい行など **レイアウト要確認**       |
| 27  | `farms/:id`                     | `farms_id.png`                      | OK  | 農場詳細・地図・圃場セクションまで表示（実行時リゾルブの効果あり）                                            |
| 28  | `farms/:id/edit`                | `farms_id_edit.png`                 | OK  | 編集画面が大きく描画（データ・地図枠あり）                                                        |
| 29  | `farms/new`                     | `farms_new.png`                     | OK  | 新規・地図あり                                                                      |
| 30  | `fertilizes`                    | `fertilizes.png`                    | OK  | **肥料一覧**に行表示（NPK 未設定はデータ次第）                                                  |
| 31  | `fertilizes/:id`                | `fertilizes_id.png`                 | OK  | 肥料詳細（データ行・ボタン）まで表示。読み込み中でない                                                  |
| 32  | `fertilizes/:id/edit`           | `fertilizes_id_edit.png`            | OK  | 見出し **「てstを編集」** など補間済み・フォーム表示                                               |
| 33  | `fertilizes/new`                | `fertilizes_new.png`                | OK  | 新規フォーム良好                                                                     |
| 34  | `interaction_rules`             | `interaction_rules.png`             | OK  | **連作ルール一覧**に行表示。サブテキストに `continuous_cultivation` 等 **raw 表記**（表記整備は別課題）      |
| 35  | `interaction_rules/:id`         | `interaction_rules_id.png`          | OK  | 連作ルール詳細表示（種別が raw `continuous_cultivation` 等はデータ表現の別検討）                      |
| 36  | `interaction_rules/:id/edit`    | `interaction_rules_id_edit.png`     | OK  | **ルール編集**フォーム充填。方向性ラベルは日本語。ルール種フィールドは raw 値のまま（表記課題）                         |
| 37  | `interaction_rules/new`         | `interaction_rules_new.png`         | 注意  | `**is_directional_label` は ja 済み**。ルール種初期値・ラベルまわりの raw は残る                   |
| 38  | `pesticides`                    | `pesticides.png`                    | 注意  | 一覧はデータあり。「Create Pesticide」等 **日英混在**                                        |
| 39  | `pesticides/:id`                | `pesticides_id.png`                 | OK  | 農薬詳細（項目・作物・害虫名）まで表示                                                          |
| 40  | `pesticides/:id/edit`           | `pesticides_id_edit.png`            | OK  | **「tを編集」**・ドロップダウン・説明まで表示。`title_default`／`{{name}}` 補間は動作                   |
| 41  | `pesticides/new`                | `pesticides_new.png`                | 注意  | タイトル・ラベルが英語寄り＋文言混在                                                           |
| 42  | `pests`                         | `pests.png`                         | OK  | 一覧にデータ表示                                                                     |
| 43  | `pests/:id`                     | `pests_id.png`                      | OK  | 害虫詳細まで表示                                                                     |
| 44  | `pests/:id/edit`                | `pests_id_edit.png`                 | OK  | **「てstを編集」**・フォーム表示                                                          |
| 45  | `pests/new`                     | `pests_new.png`                     | OK  | 新規フォーム良好                                                                     |
| 46  | `plans`                         | `plans.png`                         | OK  | 計画一覧に実データ表示                                                                  |
| 47  | `plans/:id`                     | `plans_id.png`                      | OK  | **青森の計画**・ガント・栽培バー選択ヒントまで表示（本文読み込み完了）                                        |
| 48  | `plans/:id/optimizing`          | `plans_id_optimizing.png`           | 注意  | 「Optimizing」「Back to plan」**英語**・Progress 100%                               |
| 49  | `plans/:id/task_schedule`       | `plans_id_task_schedule.png`        | 要確認 | `GET .../api/v1/plans/58/task_schedule` の **404** を生メッセージ表示（バックエンドルート／データ別途） |
| 50  | `plans/new`                     | `plans_new.png`                     | OK  | 農場ドロップダウン・次へまで表示                                                             |
| 51  | `plans/select-crop`             | `plans_select-crop.png`             | 注意  | 「農場IDが指定されていません」— **冷スタート URL** 前提として仕様どおり                                   |
| 52  | `weather`                       | `weather.png`                       | 注意  | 見出し「Weather」・**気温チャート空**                                                     |


## 集計（参考）


| 結果  | 件数  |
| --- | --- |
| OK  | 35  |
| 注意  | 9   |
| 要確認 | 8   |


## 作物一覧（`crops`）補足

`with-api` では `crops.png` 自体がログイン後の一覧になるため、別撮影の `crops.logged-in.png` は **比較用レガシー**に近い。差し替え不要なら README の手順は任意。

## 指摘の詳細（横断）

1. **詳細・編集の「読み込み中」キャプチャ**
  **with-api 再実行後**、マスタ・計画詳細の多くは **データ表示まで到達**（`waitForCaptureStable`＋リゾルブの併用で実害解消を確認）。残るのは **API エラー時**（#7 読み込み失敗、#49 404）や **i18n キー露出ページ**。
2. **entry-schedule 作物目安（#7）**
  スピナーではなく **読み込み失敗 UI**。リゾルブ id・クエリ・バックエンドを切り分け。
3. **task_schedule（#49）**
  解決済み plan id に対し **404**。PNG に実 URL あり。アプリ側ルートまたはデータ有無を確認。
4. **i18n 未解決**
  ログイン、about、privacy、terms 等。編集見出しの `%{name}` 系は **マスタ系で修正済み**（再キャプチャで確認）。
5. **言語・raw 表記**
  農薬 UI 英語残り、連作ルール `continuous_cultivation` 表示、最適化英語など。製品見直しは別タスク。
6. **キャプチャ環境**
  セッションありのため未ログイン想定ページでもヘッダがログイン状態になることがある。静的ページでは「確認中…」が残る例あり。

---

**総評**: 環境再起動後の **with-api 全件キャプチャ**で、**農作業・作物・肥料・害虫・農薬・連作編集・計画詳細（ガント）**はいずれも **本章が読める状態**で撮れている。課題は **作物目安の読み込み失敗（#7）**、**task_schedule 404（#49）**、静的ページ **i18n**、**raw／英語混在**に集約。CSS トークン監査は `npm run audit:css-tokens` を正とする。