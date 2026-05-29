# lib/domain → Rust 移行プログラム

`ARCHITECTURE.md` の方針（domain は純粋で太く、adapter は薄く、Rust へ移行可能）に沿い、**`lib/domain` 全 bounded context の振る舞い**を `crates/agrr-domain` へ段階移植するための単一プログラムです。

**ステータス（2026-05-29）**: 全コンテキスト `phase: done`（[`TRACKING.md`](./TRACKING.md)）。**[`app-rust-stack`](../app-rust-stack/) P6 着手の domain ブロッカーは解消**。adapter の §P4 残留は gateway 移行ドキュメントで app 移植時に継続。

本番 HTTP・adapter・Rails 廃止の終着スタックは [`app-rust-stack`](../app-rust-stack/) を参照。

## 読む順（設計 → 開発 → テスト）

| 順 | 文書 | 内容 |
|----|------|------|
| 0 | [app-rust-stack/PROVISIONAL-STACK.md](../app-rust-stack/PROVISIONAL-STACK.md) | **終着スタック**（Axum・adapter・ストラングラー） |
| 1 | [PROGRAM.md](./PROGRAM.md) | フェーズ・ウェーブ・完了定義・ガバナンス |
| 2 | [ARCHITECTURE.md](./ARCHITECTURE.md) | クレート構成・型の約束・レイヤ対応 |
| 3 | [TEST-STRATEGY.md](./TEST-STRATEGY.md) | R0〜R4 テスト層・パリティ・CI（R4 は P6、詳細は Stack） |
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
- **終着スタック・ストラングラー**: [`app-rust-stack/`](../app-rust-stack/)
- Gateway 整備（adapter 移植の前提）: [`gateway-domain-logic-migration.md`](../../gateway-domain-logic-migration.md)
- Ruby domain-lib: `bin/domain-lib-test`
