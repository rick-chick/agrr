# Test Directory

## 実行（必ず test-common 経由）

```bash
./bin/test                                                    # cargo + R4（CI 同等）
.cursor/skills/test-common/scripts/run-test-rust-domain.sh    # agrr-domain
scripts/run-rust-contract-tests.sh                            # R4（agrr-r4-contract + co-located agrr-server）
.cursor/skills/test-common/scripts/run-test-frontend.sh       # Angular
```

詳細: [`.cursor/skills/test-common/SKILL.md`](../.cursor/skills/test-common/SKILL.md)、[P8 — Rails シェル削除](../docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)。

## レイヤ

| 領域 | 置き場 | ランナー |
|------|--------|----------|
| API/WS 契約（R4） | `crates/agrr-r4-contract` + co-located `agrr-server` | `run-rust-contract-tests.sh` |
| ドメイン | `crates/agrr-domain` | `run-test-rust-domain.sh` |
| フロント E2E | `frontend/e2e` | Playwright（認証・主要画面） |

**P8.6（2026-06-02）**: Ruby `test/contract/**`・`Gemfile`・`app/models` を削除。旧 Ruby 契約の回帰は **E2E** と **`agrr-domain` / adapter 単体** に委譲。

## ガイドライン

契約テストの要件は [docs/TESTING_GUIDELINES.md](../docs/TESTING_GUIDELINES.md) を参照。
