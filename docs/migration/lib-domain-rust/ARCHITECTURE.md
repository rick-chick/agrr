# Rust ドメイン層アーキテクチャ

## レイヤ対応

| Ruby (`lib/domain`) | Rust (`crates/agrr-domain`) | 備考 |
|---------------------|----------------------------|------|
| `entities/` | `src/<ctx>/entities/` | `Copy` / owned データ |
| `dtos/` | `src/<ctx>/dtos/` | `serde` 可（FFI/将来 API） |
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
  agrr-domain-ffi/         # P6: cdylib + magnus（未作成）
ext/
  agrr_domain/             # P6: Ruby extension エントリ（未作成）
```

### モジュール公開

- クレートルート: `agrr_domain::shared::...`, `agrr_domain::crop::...`
- Ruby 定数 `Domain::Crop::...` との対応は **FFI 層でマッピング**（P6）。P0–P5 は Rust テストのみ。

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

## Ruby 境界（P6 以降）

| 方式 | 用途 |
|------|------|
| **magnus**（推奨） | Cloud Run 同一プロセスで Interactor を段階差し替え |
| **JSON 子プロセス** | agrr デーモンと同様の隔離が必要な場合のみ |

FFI 境界で渡すのは **スカラー・JSON 文字列・Vec** に限定。ActiveRecord を Rust に渡さない。

## 依存クレート（初期）

- `serde`, `serde_json` — DTO シリアライズ（テスト・将来 FFI）
- `thiserror` — ドメインエラー
- `chrono` — 日付（`clock_port` 代替；TZ は edge 注入）
- `rust_decimal` — BigDecimal 代替（`TypeConverters::BigDecimalConverter` 対応時）

## 命名

- Rust: `snake_case` モジュール、`PascalCase` 型
- ファイル: Ruby `crop_create_interactor.rb` → `crop_create_interactor.rs`
- Gateway trait: `CropGateway`（Ruby `CropGateway` と同名）
