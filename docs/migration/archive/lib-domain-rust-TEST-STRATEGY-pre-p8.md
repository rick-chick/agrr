> **履歴（P8 以前）** — 現行は [`../lib-domain-rust/TEST-STRATEGY.md`](../lib-domain-rust/TEST-STRATEGY.md)。

# テスト戦略（lib/domain Rust 移行）

## テスト層（R0–R4）

| 層 | 実行 | 目的 |
|----|------|------|
| **R0 Ruby domain-lib 追加** | `run-test-domain-lib.sh`（新規 `test/domain/**`） | **未テストの lib/domain 表面**に観測可能な振る舞いテストを先に書く |
| **R1 Rust 単体** | `run-test-rust-domain.sh` → `cargo test` | R0 と同等ケースのパリティ（高速） |
| **R2 Ruby domain-lib 回帰** | `run-test-domain-lib.sh` | 移行期の Ruby 回帰（Rails なし） |
| **R3 Rails 統合** | `run-test-rails.sh` | Controller → Presenter → Interactor 経路（本番経路の回帰） |

### R0 の必須ルール（2026-05 方針）

1. `lib/domain` に **専用の domain-lib テストが無い** Interactor / Policy / Calculator / Mapper は、Rust 移植 **前に** `test/domain/<context>/` を追加する。
2. `crates/agrr-domain` の `mod.rs` に **Deferred（no test/domain …）** と書いて Rust だけ先に進めることは **禁止**（未テスト表面は R0 を先に GREEN）。
3. R0 で追加したテスト名は、R1 パリティの `#[test]` コメントに **Ruby テスト名を引用**する（既存パリティ手順と同じ）。

**ルール**: Rust 化したモジュールは **R0 → R1 + R2** を必ず GREEN にしてから `TRACKING.yaml` の `phase: done`。R3 は本番経路の回帰として PR / リリース前に GREEN を維持する。

### R4 契約テスト（HTTP / WebSocket）

P6 ルート切替のゲート。手順・複製元・置き場所は [`app-rust-stack/PROVISIONAL-STACK.md`](../app-rust-stack/PROVISIONAL-STACK.md)（**R4 契約テスト**節）が正。

| 層 | 実行 | 目的 |
|----|------|------|
| **R4 契約** | 移行期: `run-test-rails.sh test/contract` | 現行 `test/channels/**`・`test/controllers/api/**` 等から写した HTTP/WS 振る舞い |
| **R4（Rust）** | P6 以降: `agrr-server` contract tests | 切替先ルートで同一アサーション GREEN |

**ルール**: R4 は新シナリオを増やさず、切替 BC に対応する既存統合テストの観測点を写す。BC 切替 PR では **R4 GREEN** を [`PROVISIONAL-STACK.md`](../app-rust-stack/PROVISIONAL-STACK.md) のゲートと併記する。

## パリティテスト

1. 対象 Ruby テストファイルを特定（例: `test/domain/shared/policies/crop_policy_test.rb`）
2. テスト名・入力・期待値を Rust `mod tests` に移植
3. コメントで Ruby 側の `test "..."` 名を引用（トレーサビリティ）

```rust
#[test]
fn view_allowed_denies_other_user_non_reference_crop() {
    // Ruby: test "view_allowed? denies other user non-reference crop"
    ...
}
```

## CI

- ワークフロー: `.github/workflows/rust-domain-test.yml`
- `main` / PR で `cargo test -p agrr-domain`（`run-test-rust-domain.sh` と同じ。ワークスペース全体は adapter crate 用）
- Rails テストとは **ジョブ分離**（Rust toolchain セットアップを軽量に）

## 完了判定（コンテキスト単位）

- [ ] `crates/agrr-domain/src/<ctx>/` に該当 Ruby ファイル数と同等の公開 API
- [ ] R1 で `test/domain/<ctx>/` と 1:1 相当のケース数（`TRACKING.yaml` の `parity_tests_rust` ≥ `parity_tests_ruby`）
- [ ] R0・R1・R2 GREEN

## 遅延・性能

- `cargo test` 全体は 60 秒未満を維持（P5 完了時点の目標）
- 0.5 秒超のテストは [`test-slow-detection`](../../../.cursor/skills/test-slow-detection/SKILL.md) と同様に記録
