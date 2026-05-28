# lib/domain → Rust 移行プログラム

`ARCHITECTURE.md` の方針（domain は純粋で太く、adapter は薄く、Rust へ移行可能）に沿い、**`lib/domain` 全 824 ファイル相当の振る舞い**を Rust へ段階移行するための単一プログラムです。

## 読む順（設計 → 開発 → テスト）

| 順 | 文書 | 内容 |
|----|------|------|
| 1 | [PROGRAM.md](./PROGRAM.md) | フェーズ・ウェーブ・完了定義・ガバナンス |
| 2 | [ARCHITECTURE.md](./ARCHITECTURE.md) | クレート構成・Ruby 境界・FFI 方針 |
| 3 | [TEST-STRATEGY.md](./TEST-STRATEGY.md) | R0〜R3 テスト層・パリティ・CI |
| 3b | [BACKLOG-test-first.yaml](./BACKLOG-test-first.yaml) | **R0 先行**の未テスト一覧（機械可読） |
| 3c | [P5-cultivation-plan-design.md](./P5-cultivation-plan-design.md) | Wave-5 設計・スライス順 |
| 4 | [slices/shared-p1-design.md](./slices/shared-p1-design.md) | shared BC の P1 設計・残タスク |
| 5 | [TRACKING.md](./TRACKING.md) | **進捗の正**（コンテキスト別ステータス） |
| 6 | [TRACKING.yaml](./TRACKING.yaml) | 機械可読な進捗・ウェーブ定義 |

## 日常コマンド

```bash
# インベントリ更新 + TRACKING.md 再生成
./scripts/sync-lib-domain-rust-tracking.sh

# Rust ドメイン単体テスト（Rails 不要）
.cursor/skills/test-common/scripts/run-test-rust-domain.sh

# 既存 Ruby domain-lib（移行完了まで併走）
.cursor/skills/test-common/scripts/run-test-domain-lib.sh
```

## 関連

- 規約: [`ARCHITECTURE.md`](../../../ARCHITECTURE.md)
- Gateway 整備（Rust 化の前提）: [`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md)
- Ruby domain-lib: `bin/domain-lib-test`
