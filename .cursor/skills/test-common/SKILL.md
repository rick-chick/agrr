---
name: test-common
description: >-
  Runs Rust domain (cargo), R4 contract, and Frontend tests via project scripts
  (run-test-rust-domain.sh, run-rust-contract-tests.sh, run-test-frontend.sh).
  Use when the user asks to run tests, get test results, list failures, or any request that requires
  executing the test suite (e.g. テストを実行, テストを流す, rails test, npm test).
disable-model-invocation: false
---

# テスト共通実行（Test Common）

## 手順

1. **このスキルを読む**（テスト実行・失敗一覧取得・洗い出しなど、テストスイートを走らせる依頼では必ず適用）。
2. **下記スクリプトのみを使う。** `bundle exec rails test` / `rails test` は **廃止**（P8.6）。`npm test` の直接実行も禁止。
3. **プロセス監視を行う** skill process-monitorを用いてテストの結果を得る

## 正（本番 API/WS）

**R4 契約**: `scripts/run-rust-contract-tests.sh`（`CONTRACT_RUNTIME=rust`、co-located `agrr-server` + `crates/agrr-r4-contract`）。広い API 回帰は Playwright E2E + `agrr-domain`。

## 実行

- **agrr-domain**: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh [ARGS]`。既定は `cargo test -p agrr-domain`。
- **R4 契約**: `scripts/run-rust-contract-tests.sh`。[`P8-RAILS-SHELL-REMOVAL.md`](../../../docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)
- **Frontend（Angular）**: `.cursor/skills/test-common/scripts/run-test-frontend.sh [ARGS]`
- **CI 同等の一括**: `./bin/test`（cargo → R4）
- **run-test-rails.sh**: R4 へのエイリアス（後方互換。Ruby テストは実行しない）

## ドメインの正

`crates/agrr-domain`（`run-test-rust-domain.sh`）。`lib/domain/` は P7 で削除済み。
