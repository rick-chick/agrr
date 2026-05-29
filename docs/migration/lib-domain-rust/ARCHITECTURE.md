# Rust ドメイン層アーキテクチャ

## レイヤ対応

| Ruby (`lib/domain`) | Rust (`crates/agrr-domain`) | 備考 |
|---------------------|----------------------------|------|
| `entities/` | `src/<ctx>/entities/` | `Copy` / owned データ |
| `dtos/` | `src/<ctx>/dtos/` | `serde` 可（テスト・シリアライズ） |
| `policies/` | `src/<ctx>/policies/` | 純関数・`User` 等のスカラー入力 |
| `mappers/` | `src/<ctx>/mappers/` | I/O なし |
| `interactors/` | `src/<ctx>/interactors/` | Gateway trait を引数で受け取る |
| `ports/`（output） | `src/<ctx>/ports/output.rs` | trait = `on_success` / `on_failure` |
| `ports/`（input） | `src/<ctx>/ports/input.rs` | サブステップ用 |
| `gateways/`（interface） | `src/<ctx>/gateways/mod.rs` | **trait のみ** |
| `shared/ports/` | `src/shared/ports/` | clock, logger 等 |
| `shared/gateways/` | `src/shared/gateways/` | user lookup 等 |

**実装しないもの（Rust クレート外）**: `app/adapters/**`, `CompositionRoot`, ActiveRecord, `render`。

## クレート構成

```
Cargo.toml                 # workspace root
crates/
  agrr-domain/             # 純粋ドメイン（#![no_std] は採用しない — std + serde）
    src/
      lib.rs
      shared/
      <bounded_context>/
```

### モジュール公開

- クレートルート: `agrr_domain::shared::...`, `agrr_domain::crop::...`
- 移行期の Ruby `Domain::...` は `lib/domain` に残す。本プログラムは **`agrr-domain` の実装と R0–R2 パリティ**まで。本番接続は [`app-rust-stack`](../app-rust-stack/)（Axum + Rust adapter）。

## 型の約束

### `User`

Ruby の `user.admin?` / `user.id` / `anonymous?` を Rust では明示 struct にする。

```rust
pub struct User {
    pub id: i64,
    pub admin: bool,
    pub anonymous: bool,
}
```

### 属性マップ（Policy 正規化）

Ruby の `Hash` + `symbolize_keys` は `AttrMap`（`BTreeMap<String, AttrValue>`）に対応。

### エラー

Ruby の `Domain::Shared::Exceptions::*` は `thiserror` enum で定義し、Interactor が `Result` で返す。

## Interactor パターン（Rust）

```rust
pub struct CropListInteractor<G: CropGateway> {
    gateway: G,
    output: Box<dyn CropListOutputPort>,
}

impl<G: CropGateway> CropListInteractor<G> {
    pub fn call(&self, input: CropListInput) -> Result<(), DomainError> {
        let filter = CropPolicy::index_list_filter(&input.user);
        let rows = self.gateway.list(&filter)?;
        self.output.on_success(rows);
        Ok(())
    }
}
```

テストでは `G` に mockall または手書き Fake を使用。

## 非採用（Ruby 本番接続）

| 案 | 判定 |
|----|------|
| magnus / `ext/agrr_domain` による Ruby プロセス内 FFI | **非採用** — P0–P5 は `agrr-domain` 実装と R0–R2 パリティのみ。移行期の本番経路は Ruby `lib/domain` + Rails adapter |
| 同一プロセスでの段階的 Interactor 差し替え（FFI デリゲート） | **非採用** — ルート単位のストラングラーは [`app-rust-stack`](../app-rust-stack/)（Axum + Rust adapter、P6–P7） |

## 依存クレート（初期）

- `serde`, `serde_json` — DTO シリアライズ（テスト・デバッグ）
- `thiserror` — ドメインエラー
- `time` — 日付（`ClockPort`；TZ は edge 注入）
- `rust_decimal` — BigDecimal 代替（`TypeConverters::BigDecimalConverter` 対応時）

## 命名

- Rust: `snake_case` モジュール、`PascalCase` 型
- ファイル: Ruby `crop_create_interactor.rb` → `crop_create_interactor.rs`
- Gateway trait: `CropGateway`（Ruby `CropGateway` と同名）
