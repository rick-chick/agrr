# テスト戦略（`agrr-domain` — 現行）

> 移行期（R0–R3 Ruby `test/domain`・Ruby R4 契約）の手順は [`../archive/lib-domain-rust-TEST-STRATEGY-pre-p8.md`](../archive/lib-domain-rust-TEST-STRATEGY-pre-p8.md)。

## 層と責務

| 層 | 実行 | 責務 |
|----|------|------|
| **ドメイン** | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` | Interactor / Policy / Calculator / Mapper（`crates/agrr-domain`） |
| **Adapter** | `cargo test -p agrr-adapters-sqlite` 等 | 永続化・外部 I/O の狭い振る舞い（ユースケース網羅は domain） |
| **R4 スモーク** | `scripts/run-rust-contract-tests.sh` | co-located `agrr-server` + **`agrr-r4-contract`（health・`/cable` のみ）** — 業務ルールは書かない |
| **E2E** | `frontend` Playwright | 画面・認証・主要 API フロー |

HTTP/WS の広い回帰は Ruby 契約ではなく **E2E + domain + adapter**（[`P8-RAILS-SHELL-REMOVAL.md`](../app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）。

## 変更時のルール

1. ドメイン振る舞い → `crates/agrr-domain/test/**` に観測可能なテストを追加（TDD は [`tdd-on-edit`](../../../.cursor/skills/tdd-on-edit/SKILL.md)）。
2. ルート配線・スタック起動 → `agrr-r4-contract` に最小スモークのみ（重複する業務アサーションは増やさない）。
3. 実行は **test-common** 経由（[`test-common/SKILL.md`](../../../.cursor/skills/test-common/SKILL.md)）。

## CI

| ジョブ | 内容 |
|--------|------|
| `.github/workflows/rust-domain-test.yml` | `cargo test`（domain） |
| `.github/workflows/rails-test.yml` | `./bin/test`（domain + R4；名称は歴史的） |

## 性能

- 0.5 秒超のテストは [test-slow-detection](../../../.cursor/skills/test-slow-detection/SKILL.md) を参照。
