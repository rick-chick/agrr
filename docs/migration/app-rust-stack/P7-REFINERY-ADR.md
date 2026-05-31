# ADR: P7 schema ownership — refinery + Rails sunset

> **ステータス**: 実施中 — 手順は [P7-MIGRATION-RUNBOOK.md](./P7-MIGRATION-RUNBOOK.md)、実装は `crates/agrr-migrate`  
> **前提**: P6 全 BC ルート切替完了、`rails-backend` を URL map から除去済み

## コンテキスト

- P6 中は **`db/migrate` / `db/cache_migrate` を Rails のみ**が発行する（[`PROVISIONAL-STACK.md`](./PROVISIONAL-STACK.md)）。
- 終着は Rust 単体 Cloud Run + Litestream。`lib/domain` と Rails adapter は削除する。

## 決定

| 項目 | 内容 |
|------|------|
| P7 マイグレーション | **[refinery](https://github.com/refinery/refinery)** で Rust 側に移管 |
| ダウンタイム | 単一ライター維持。既存 DB は `schema stamp` + 差分 `schema run` のみ（baseline 再適用禁止） |
| データ | `agrr-migrate data apply`（**起動時は実行しない**）。履歴は primary の `data_migration_history` |
| 地域 | `jp` / `in` / `us` |
| `cable` SQLite | WS プロセス内化に伴い **廃止** |
| 削除 undo | **Angular のみ**（Rust server template は採用しない） |

## P7 出口チェックリスト

1. URL map に `rails-backend` が無い（`/up` 含め Rust または監視専用へ）
2. `lib/domain/` 削除、Rails 本番イメージ廃止
3. `cargo test --workspace` + R4 contract GREEN on Rust runtime
4. refinery が primary / cache スキーマを所有
5. Litestream 単一ライターが Rust のみ

## 非ゴール

- agrr Python デーモンの Rust 化
- API / DTO 契約変更（移行期原則禁止の最終確認のみ）
