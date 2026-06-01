# Test Directory

## 実行（必ず test-common 経由）

**直接 `bundle exec rails test` や `rails test` を実行しない**（開発 DB 破壊防止）。`test/test_helper.rb` が RAILS_ENV≠test を拒否する。

```bash
./bin/test                                                    # cargo + R4（CI 同等）
.cursor/skills/test-common/scripts/run-test-rails.sh          # R4 契約（ファイル指定時。引数なしはスキップ）
.cursor/skills/test-common/scripts/run-test-rust-domain.sh    # agrr-domain（cargo）
scripts/run-rust-contract-tests.sh                            # R4 契約（本番 API/WS の正）
.cursor/skills/test-common/scripts/run-test-frontend.sh       # Angular
```

詳細: [`.cursor/skills/test-common/SKILL.md`](../.cursor/skills/test-common/SKILL.md)、[P8 — Rails シェル削除](../docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)。

## レイヤ

| 領域 | 置き場 | ランナー |
|------|--------|----------|
| API/WS 契約（正） | co-located **`agrr-server`** + `crates/agrr-r4-contract` + `test/contract/**`（Ruby は fixture のみ） | `run-rust-contract-tests.sh`（Rust → Ruby の順） |
| ドメイン | `crates/agrr-domain` | `run-test-rust-domain.sh` |
| 契約ハーネス（縮小中 P8） | `test/contract/**`, `test/factories/**`, `app/models/**` | 同上。API 実装は Rails にない |

`test/domain/`・`test/adapters/`・`lib/domain/` は P7 で削除済み。

## テストファイル構成（P8.5 以降）

```
test/
├── contract/        # R4 ハーネス（Minitest + ActiveRecord fixture → agrr-server）
├── factories/       # FactoryBot（契約テスト用 fixture）
└── support/         # 契約テスト補助

crates/agrr-r4-contract/   # P8.6: 重い契約のみ Rust 化。auth_me 等の薄い auth は移植せず Gem 削除時に Ruby 除去
```

## ガイドライン

契約テストの要件は [docs/TESTING_GUIDELINES.md](../docs/TESTING_GUIDELINES.md) を参照。
