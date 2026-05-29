# R4 contract tests (P6)

BC ルート切替時に、当該 `test/controllers/api/v1/**` の観測可能な振る舞いを Rust ランタイムでも固定する。

| ゲート | 状態 |
|--------|------|
| Ruby Gateway §P4（read snapshot） | field_cultivation（sync plan read 3 分割、climate_progress）+ cultivation_plan（rest plan / timeline / adjust / optimization read）— 移行済み（2026-05-29） |
| `agrr-adapters-sqlite` | **参照実装のみ**（`FieldCultivationClimateSourceSqliteGateway`）。本番 DB 向け R4・URL map は未着手 |
| `agrr-server` | `/health` + サンプル read。composition パターンの雛形 |

- 正: [`docs/migration/app-rust-stack/PROVISIONAL-STACK.md`](../docs/migration/app-rust-stack/PROVISIONAL-STACK.md) — R4 契約
- Sqlite 単体: `cargo test -p agrr-adapters-sqlite`

**P6 切替 PR で必須**: 対象 BC の R4 GREEN + URL map（ADR）+ 単一ライター確認。
