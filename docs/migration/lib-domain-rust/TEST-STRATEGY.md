# テスト戦略（lib/domain Rust 移行）

## 4 層のテスト（R0 追加）

| 層 | 実行 | 目的 |
|----|------|------|
| **R0 Ruby domain-lib 追加** | `run-test-domain-lib.sh`（新規 `test/domain/**`） | **未テストの lib/domain 表面**に観測可能な振る舞いテストを先に書く |
| **R1 Rust 単体** | `run-test-rust-domain.sh` → `cargo test` | R0 と同等ケースのパリティ（高速） |
| **R2 Ruby domain-lib 回帰** | `run-test-domain-lib.sh` | 移行期の Ruby 回帰（Rails なし） |
| **R3 Rails 統合** | `run-test-rails.sh` | Controller → Presenter → Interactor 経路 |

### R0 の必須ルール（2026-05 方針）

1. `lib/domain` に **専用の domain-lib テストが無い** Interactor / Policy / Calculator / Mapper は、Rust 移植 **前に** `test/domain/<context>/` を追加する。
2. `crates/agrr-domain` の `mod.rs` に **Deferred（no test/domain …）** と書いて Rust だけ先に進めることは **禁止**（バックログは [`BACKLOG-test-first.yaml`](./BACKLOG-test-first.yaml)）。
3. R0 で追加したテスト名は、R1 パリティの `#[test]` コメントに **Ruby テスト名を引用**する（既存パリティ手順と同じ）。

**ルール**: Rust 化したモジュールは **R0 → R1 + R2（FFI 前）または R1 + R3（FFI 後）** を必ず GREEN にしてから `TRACKING.yaml` の `phase: done`。

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
- `main` / PR で `cargo test --workspace`
- Rails テストとは **ジョブ分離**（Rust toolchain セットアップを軽量に）

## FFI 後の追加テスト

- `test/ext/agrr_domain/` — Ruby から Rust を呼ぶスモーク（P6）
- 既存 domain-lib テストは **実装が FFI に切り替わっても** 振る舞い不変

## 完了判定（コンテキスト単位）

- [ ] `crates/agrr-domain/src/<ctx>/` に該当 Ruby ファイル数と同等の公開 API
- [ ] R1 で `test/domain/<ctx>/` と 1:1 相当のケース数（`TRACKING.yaml` の `parity_tests_rust` ≥ `parity_tests_ruby`）
- [ ] FFI デリゲート後、R2 または R3 GREEN
- [ ] Ruby 重複実装削除（または `shim` 明示）

## 遅延・性能

- `cargo test` 全体は 60 秒未満を維持（P5 完了時点の目標）
- 0.5 秒超のテストは [`test-slow-detection`](../../../.cursor/skills/test-slow-detection/SKILL.md) と同様に記録
