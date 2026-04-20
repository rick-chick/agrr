# Hotwire / Stimulus 撤去計画（T-040）

## 依存の所在（2026-04 時点）

| 種別 | 所在 |
|------|------|
| npm | ルート `package.json`: `@hotwired/stimulus`, `@hotwired/turbo-rails`, 他 |
| Gem | `Gemfile`: `turbo-rails`, `stimulus-rails`, `jsbundling-rails`（想定） |
| ビルド出力 | `app/assets/builds/application.js` に Turbo バンドルが含まれる |
| Stimulus | `app/javascript/controllers/*.js`（`data-controller` と対応） |

## Rails View での `data-controller` / `data-turbo-track`（抜粋）

| 画面 / パーツ | 属性 | 備考 |
|---------------|------|------|
| `layouts/application.html.erb` | `data-turbo-track` | 全ページ |
| `layouts/application.html.erb` | `data-controller="undo-toast"` | 撤去時は Angular 側へ |
| `shared/_navbar.html.erb` | `navbar`, `dropdown` | HTML ナビ |
| `shared/_cookie_consent_banner.html.erb` | `cookie-consent` | Angular に既存相当あり得る |
| `plans/show.html.erb`, `public_plans/results.html.erb` | `plans-show`, Gantt 用 `javascript_include_tag` | **未 Angular 化の重い画面** |
| `plans/optimizing.html.erb`, `public_plans/optimizing.html.erb` | `optimizing` | 同上 |
| `plans/task_schedules/show.html.erb` | `task-schedule-timeline` | 同上 |
| `crops/_task_schedule_blueprints_section.html.erb` | `task-blueprint-card-drag` | マスタ HTML |
| `fertilizes/_form.html.erb` | `fertilize-ai` | AI 補助 |
| `api_keys/show.html.erb` | `copy-to-clipboard` | 小機能 |

## 撤去可否の判断

- **Angular 置換済み**: マスタ CRUD・公開プラン作成フロー・`entry-schedule` など（`frontend/`）。
- **未置換（HTML + Stimulus 依存）**: 計画 Gantt・タスクスケジュールタイムライン・最適化待機画面・一部マスタフォーム（AI・ブループリント DnD）。

## 推奨フェーズ（T-041〜T-043 前提）

1. 上表「未置換」を Angular へ移行する設計タスクを **画面単位** で起票する。
2. 全画面が Angular またはサーバー描画のみ（JS 不要）になったことを確認してから T-041（ルート package 依存削除）に着手。
3. T-042 で Gem・Propshaft・`app/javascript` を削除（本番 Dockerfile・CI のアセット手順を同期）。

## 参照

- ロードマップ Phase 4（T-040〜T-043）
- `ARCHITECTURE.md`（フロント配信・SPA 方針）

---

## 前提達成状況（2026-04-20 追記）

- **T-041〜T-043 は未着手**（上表の未 Angular 化画面が残存する限り、ロードマップ Phase 3 のゲートにより着手しない）。
- **ユーザー確認**: Gantt / optimizing / task schedule HTML・マスタ AI 等の Angular 移行完了を確認したうえで Hotwire 撤去タスクを起票すること。
