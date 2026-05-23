# AGRR - 農業計画支援システム

Rails 8 + SQLite + Google Cloud Run で動く農業計画支援システム

## 🚀 クイックスタート

### 開発環境

#### 初回セットアップ

```bash
# スクリプトファイルに実行権限を付与(初回のみ)
chmod +x scripts/*.sh

# 起動(自動的にマイグレーション実行、アセットビルド)
docker compose up
```

> 💡 **注意**: スクリプトファイルの実行権限は初回セットアップ時に必要です。Dockerfile内でも設定されますが、ホスト側でも設定しておくことを推奨します。

#### 通常の起動

```bash
# 起動(自動的にマイグレーション実行、アセットビルド)
docker compose up

# テスト実行
.cursor/skills/test-common/scripts/run-test-rails.sh  # ⭐ 推奨：便利スクリプト（警告なし)
.cursor/skills/test-common/scripts/run-test-rails.sh  # 直接実行(警告なし)

⚠️ **重要**: 絶対に直接 `rails test` や `bundle exec rails test` を実行しないでください!
開発DBが壊れる可能性があります。必ず上記の専用スクリプトを使用してください。

# メモリ監視レポート確認(必要時のみ有効化)
# デフォルトでは無効(起動時間短縮のため)
# 有効化: ENABLE_MEMORY_MONITOR=true docker compose up
./scripts/view_memory_report.sh
```

アクセス: http://localhost:3000

> 💡 **メモリ監視はデフォルトで無効**(起動時間短縮のため)。必要時は `ENABLE_MEMORY_MONITOR=true docker compose up` で有効化。

#### 新規計画作成で AGRR を使う場合

新規計画作成(栽培計画の最適化)には AGRR デーモンが必要です。

- **Docker 利用時**: `USE_AGRR_DAEMON=true docker compose up` でデーモンを起動。バイナリは `lib/core/agrr` に配置するか、`AGRR_BIN_PATH` で指定。
- **ローカルで `rails s` を直接起動する場合**:
  1. バイナリをビルド: `cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr`
  2. `lib/core/agrr` に配置されていれば、最適化実行時にデーモン自動起動を試行します。
  3. または手動起動: `./lib/core/agrr daemon start`(別ターミナルで実行)

### デプロイ

```bash
# Production環境
.cursor/skills/deploy-server/scripts/gcp-deploy.sh

# Frontend
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
```

---

## 📚 主要ドキュメント

### アーキテクチャ

| ドキュメント | 用途 |
|------------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | システムアーキテクチャ、設計思想 |
| [CLAUDE.md](CLAUDE.md) | 規約・禁止事項の要約 |
| [docs/contracts/](docs/contracts/) | API・機能契約 |
| [docs/README.md](docs/README.md) | 全ドキュメント一覧 |

---

## 🧪 テスト

テストは **必ず test-common 経由**で実行する。生 `rails test` / `bundle exec rails test` は `test/test_helper.rb` の RAILS_ENV ガードで弾かれる（開発 DB 破壊防止）。

```bash
.cursor/skills/test-common/scripts/run-test-rails.sh        # Rails 全体
.cursor/skills/test-common/scripts/run-test-domain-lib.sh   # test/domain（Rails-free）
.cursor/skills/test-common/scripts/run-test-frontend.sh     # Angular
```

詳細・運用ルールは [.cursor/rules/rails-testing-workflow.mdc](.cursor/rules/rails-testing-workflow.mdc) と [.cursor/skills/test-common/SKILL.md](.cursor/skills/test-common/SKILL.md)。

---

## 💡 データ管理

マスターデータ(参照農場・作物)は**データベースマイグレーション**で管理されています。

各地域は**ローカル言語**でステージ名を管理:
- 🇯🇵 Japan: 47農場、15作物(日本語)
- 🇺🇸 United States: 50農場、30作物(英語)
- 🇮🇳 India: 50農場、30作物(ヒンディー语 हिंदी)

---

## 📖 詳細ドキュメント

<details>
<summary>ドキュメント</summary>

- [docs/README.md](docs/README.md) - 全ドキュメント一覧

</details>

---

## 🌐 本番環境

- **URL**: https://agrr.net
- **プラットフォーム**: Google Cloud Run
- **データベース**: SQLite + Litestream(Cloud Storageバックアップ)

---

## 🛠 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フレームワーク | Rails 8(JSON API + 一部 HTML マスタ) |
| フロント SPA | Angular 21(`frontend/`、Clean Architecture 志向のレイヤ構成) |
| フロント配信 | Google Cloud Storage + Cloud CDN(`.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh`) |
| データベース | SQLite(Solid Queue, Solid Cache, Solid Cable) |
| バックアップ | Litestream(GCS レプリカ) |
| バックエンド実行 | Google Cloud Run(`.cursor/skills/deploy-server/scripts/gcp-deploy.sh`) |
| レガシーアセット | Propshaft + jsbundling-rails + Hotwire(Turbo/Stimulus)は段階的撤去予定(ルート `package.json` / `app/javascript/`) |

アーキテクチャの詳細は [ARCHITECTURE.md](ARCHITECTURE.md) を参照。

---

**最終更新**: 2026-05-22
