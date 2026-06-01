# Test Directory

## 実行（必ず test-common 経由）

**直接 `bundle exec rails test` や `rails test` を実行しない**（開発 DB 破壊防止）。`test/test_helper.rb` が RAILS_ENV≠test を拒否する。

```bash
./bin/test                                                    # Rails 残存 + cargo + R4（CI 同等）
.cursor/skills/test-common/scripts/run-test-rails.sh          # Rails シェル回帰のみ
.cursor/skills/test-common/scripts/run-test-rust-domain.sh    # agrr-domain（cargo）
scripts/run-rust-contract-tests.sh                            # R4 契約（本番 API/WS の正）
.cursor/skills/test-common/scripts/run-test-frontend.sh       # Angular
```

詳細: [`.cursor/skills/test-common/SKILL.md`](../.cursor/skills/test-common/SKILL.md)、[P8 — Rails シェル削除](../docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)。

## レイヤ

| 領域 | 置き場 | ランナー |
|------|--------|----------|
| API/WS 契約（正） | `test/contract/**` + co-located `agrr-server` | `run-rust-contract-tests.sh` |
| ドメイン | `crates/agrr-domain` | `run-test-rust-domain.sh` |
| Rails シェル（縮小中） | `test/models`, `test/controllers`, … | `run-test-rails.sh` |

`test/domain/`・`test/adapters/`・`lib/domain/` は P7 で削除済み。

## テストファイル構成（Rails シェル残存）

```
test/
├── contract/        # R4 ハーネス（Minitest + ActiveRecord fixture）
├── models/          # AR モデル回帰
├── integration/     # 統合テスト
├── controllers/     # dev コントローラ（auth_test 等）
├── factories/       # FactoryBot（テスト補助、単体では実行しない）
└── architecture/    # 規約スキャン
```

## ガイドライン

モデル・統合テストの要件は [docs/TESTING_GUIDELINES.md](../docs/TESTING_GUIDELINES.md) を参照。
