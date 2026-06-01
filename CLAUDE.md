# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

AGRR は農業計画支援システム。**Rails 8 JSON API（HTML マスタも一部）+ Angular 21 SPA**、SQLite（Litestream で GCS にレプリカ）、Google Cloud Run で稼働。最適化や気象処理は外部の **agrr Python バイナリ／デーモン**（`lib/core/agrr`）に委譲する。

## 規約の優先順位

1. **`ARCHITECTURE.md`** — レイヤ境界・禁止事項（`## What we require`、`## Prohibited practices` 1–39）の**最上位ソース**。「既存もそう」「テストが通った」は規約の根拠にならない。
2. 該当テスト（観測可能な振る舞いを表明するもの）
3. 以下の `.cursor/rules/*.mdc`（常時適用 / 文脈依存）

`lib/domain`・gateway・`CompositionRoot`・Interactor / Presenter 配線に触れる変更では、必ず該当層の `What we require` / `Prohibited practices` を読み直す。

### 常時適用ルール

@.cursor/rules/agent-conventions.mdc
@.cursor/rules/dont-finish-task-while-process-is-running.mdc
@.cursor/rules/evidence-before-design-and-implementation.mdc
@.cursor/rules/user-request-project-alignment.mdc
@.cursor/rules/gcp-available.mdc
@.cursor/rules/implementation-consistency-with-existing.mdc
@.cursor/rules/no-convenience-tech-debt.mdc
@.cursor/rules/project-necessary-code-only.mdc
@.cursor/rules/rails-clean-architecture.mdc
@.cursor/rules/git-operational-constraints.mdc
@.cursor/rules/tdd-on-edit.mdc

### 文脈依存ルール（該当作業で参照）

@.cursor/rules/git-operational-constraints.mdc は常時適用のため上に記載。以下は文脈依存のみ。

@.cursor/rules/ca-violation-fix-architecture-gate.mdc
@.cursor/rules/feature-orchestrator.mdc
@.cursor/rules/i18n-completion-orchestrator.mdc
@.cursor/rules/rails-testing-workflow.mdc
@.cursor/rules/skill-authoring.mdc
@.cursor/rules/test-quality-core.mdc
@.cursor/rules/test-quality-checklist.mdc
@.cursor/rules/use-skills-on-edit.mdc

## アーキテクチャ要点（`ARCHITECTURE.md` 参照を前提に最低限のみ）

### バックエンドの正規バーティカルスライス（JSON API）

**1 つの JSON アクション = 1 つの Interactor 呼び出し + 1 つの Presenter（output_port 実装）**。

```
Controller → input DTO 構築・gateway / presenter 注入
   ↓
Interactor (lib/domain/<context>/interactors/) — DTO とポート型のみに依存
   ↓                        ↓
Gateway interface       Output port (presenter が実装)
(lib/domain/.../gateways)  ↓
   ↑                  view.render_response(json:, status:)
Gateway 実装
(app/adapters/<context>/gateways/)
   ↑
SQLite / ActiveRecord / HTTP
```

- **Controller** は `params` を input DTO に直し、`CompositionRoot` から gateway を取り、Presenter（`PresenterClass.new(view: self)`）を作り、Interactor に注入する。**`rescue` / `rescue_from` を「ユースケース結果の主たる振り分け」にしない**。
- **Interactor** は成功と**モデル化された失敗**を決め、`output_port.on_success(dto)` / `on_failure(dto)` を呼ぶ。`render` / 生 `params` / AR 直叩きは書かない。`on_failure` 後に `raise` で同じケースを Controller に再キャッチさせる二重経路を作らない。
- **Presenter**（`app/adapters/<context>/presenters/`）は output port を実装し、HTTP 形に写すだけ。`CompositionRoot` / `find_model` / gateway 取得・認可・本質バリデーションを置かない。
- **Gateway** は狭い永続化／I/O。表現・認可・ユースケース分岐を含めない（"画面ごとの blob を返す Gateway" は境界違反。Interactor 側で組み立てる）。
- **HTML マスタ CRUD も**同じドメインを通る。同一ユースケースは HTML と API で **同じ Interactor**。`*HtmlInteractor` / `*ApiInteractor` の分割は禁止。

### 主要なドメイン文脈（`lib/domain/<context>/`）

`agricultural_task`, `api_keys`, `auth`, `backdoor`, `contact_messages`, `crop`, `cultivation_plan`, `deletion_undo`, `farm`, `fertilize`, `field`, `field_cultivation`, `interaction_rule`, `internal_jobs`, `pest`, `pesticide`, `public_plan`, `user`, `weather_data`, `shared`。各文脈は `entities/`, `dtos/`, `gateways/`(interface), `interactors/`, `ports/`。

### 重要な禁止（よくある違反）

- `lib/domain` での `Rails.*` / `Date.current` / `Time.current` / `n.days` / AR の `.where`・`includes` 等 / `Adapters::...new` / `*Port.default`・`*Gateway.default` 等のサービスロケータ
- Interactor からの `CompositionRoot.*` 呼び出し（配線は edge）
- Presenter での `find_model` / gateway 取得・副作用（ジョブ enqueue 等）
- View（ERB）での AR 取得・関連トラバース／ビジネスルール
- `app/controllers/concerns/` や `app/models/concerns/` への**新規** `ActiveSupport::Concern`（ドメインや use-case 共有のため）
- 太い controller / `app/services/` / `rescue_from` への "横逃げ"（DTO・ポート・注入なしの relocation）

### 外部 agrr デーモン統合

`app/adapters/agrr/gateways/` が CLI / デーモンプロトコルをカプセル化（最適化、気象、進捗）。テストは `test/adapters/agrr/`。

### フロントエンド（`frontend/src/app/`、Angular 21）

依存方向: `components → usecase → domain` / `adapters → gateway tokens`。`adapters/` が HTTP 実装、`services/` は横断、`core/` に i18n・API base URL・`ListRefreshBus` 等。i18n は `@ngx-translate`（`frontend/src/assets/i18n/{ja,en}.json`）。本番ルーティングは `PathLocationStrategy`、CDN で `index.html` フォールバック。

### コアビジネスルール（リソース制限）

- **Farm**: ユーザーあたり `is_reference: false` で最大 4 件
- **Crop**: ユーザーあたり `is_reference: false` で最大 20 件
- `is_reference: true` のマスタデータは制限対象外
- 強制は **Domain-level Policies**（ユースケース境界）。ActiveRecord の validations は**安全網**のみ。

## 必須コマンド

### 開発環境（推奨: Rust スタック）

```bash
chmod +x scripts/*.sh
./scripts/load-development-reference-data.sh   # 初回 DB
./scripts/dev-rust-stack.sh                    # agrr-server + nginx :3000
cd frontend && ng serve --host 127.0.0.1
```

本番 API/WS は Rust のみ（P7 完了）。リポジトリの Rails 削除は P8（[`docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md`](docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）。

**レガシー**: `docker compose up`（Rails シェル、SPA フォールバック用）。

### テスト（**必ず test-common 経由**）

⚠️ **直接 `rails test` / `bundle exec rails test` / `npm test` を実行しない。開発 DB が壊れる。** `test/test_helper.rb` には RAILS_ENV≠test 時の即時終了ガードがある。

```bash
# Rails テスト（DB / SimpleCov / フルスタック込み・テスト専用 tmpfs）
.cursor/skills/test-common/scripts/run-test-rails.sh [ARGS]

# agrr-domain（cargo）
.cursor/skills/test-common/scripts/run-test-rust-domain.sh [ARGS]

# R4 契約（Rust ランタイム・本番経路の正）
scripts/run-rust-contract-tests.sh

# Frontend（Angular）
.cursor/skills/test-common/scripts/run-test-frontend.sh [ARGS]
```

実行順序: **個別ファイル指定で GREEN → ファイル指定なしで全体実行**（個別が通っても他ファイルへ波及がある）。実行完了後、**0.5 秒を超えるテスト**がないか確認する（手順は `.cursor/skills/test-slow-detection/SKILL.md`）。

### シェル実行と完了報告

テスト・ビルドなど**終了が非自明な処理**では `process-monitor` スキル経由で **exit_code 取得後**にのみ成功・失敗を断定する。実行中に「完了」「成功」と書かない。

### デプロイ

```bash
.cursor/skills/deploy-server/scripts/gcp-deploy.sh    # Production agrr-server（agrr.net API/WS）
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh  # Frontend → GCS + Cloud CDN
.cursor/skills/gcp-test-local/SKILL.md              # GCP test（agrr-test）+ ローカル ng serve proxy
```

### Git 操作の制約

**`git checkout` / `git switch` / `git reset` / `git restore`** など**ブランチ・HEAD・作業ツリーを戻す操作**は、ユーザーの明示許可なしには実行しない（詳細は [`.cursor/rules/git-operational-constraints.mdc`](.cursor/rules/git-operational-constraints.mdc)、**常時適用**）。`git add` / `git commit` / `git status` / `git diff` / `git log` は可。`git push` や force 系はユーザー明示時のみ。

## ワークフロー（CA 違反修正・新規実装）

新規実装も違反修正も**同じワークフロー**（セクション0〜6）を踏む。詳細は `.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md`。

1. **セクション0 — 洗い出し**: `ARCHITECTURE.md` の規約とコードベースを照らす。`git diff` だけで代替しない。
2. **セクション4 — ARCHITECTURE.md ゲート（1 回目・2 回目）**: `.cursor/rules/ca-violation-fix-architecture-gate.mdc` の手順で禁止 1–39 と照合・記録出力する。Rails / `frontend/` のみの差分でも同一フォーマット。
3. **セクション6 — コミット・再洗い出し**: コミットメッセージで違反した禁止番号を明示するとよい。**ユーザー発話待ちでの停止**（「続けますか」）は禁止。

便宜による境界逸脱（"後で直す"・コメントへの一言・暫定マージ）は `.cursor/rules/no-convenience-tech-debt.mdc` 違反。規約と両立しない経路に当たったら**実装を止めてユーザーに報告**する。

## 参考ドキュメント

- [ARCHITECTURE.md](ARCHITECTURE.md) — 規約本体（禁止 1–30、レイヤ境界）
- [README.md](README.md) — クイックスタート、技術スタック、運用リンク
- [docs/README.md](docs/README.md) — 補助ドキュメント索引
- [.cursor/rules/rails-testing-workflow.mdc](.cursor/rules/rails-testing-workflow.mdc) — テスト運用ルール
