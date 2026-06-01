# lib/domain → Rust 移行プログラム

**ステータス（2026-05-29）**: 全 19 bounded context `phase: done`（[`TRACKING.yaml`](./TRACKING.yaml) / [`TRACKING.md`](./TRACKING.md)）。

本番 HTTP・Rails 廃止は [`app-rust-stack/`](../app-rust-stack/)（完了記録: [`PRODUCTION-CUTOVER-STATUS.md`](../app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)）。

## 参照（現行）

| 文書 | 内容 |
|------|------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | `agrr-domain` クレート構成・型の約束 |
| [TEST-STRATEGY.md](./TEST-STRATEGY.md) | 現行テスト層（domain / adapter / R4 / E2E） |
| [TRACKING.yaml](./TRACKING.yaml) | 進捗（機械可読） |
| [TRACKING.md](./TRACKING.md) | 進捗サマリー（`sync-lib-domain-rust-tracking.sh` で生成） |
| [app-rust-stack/](../app-rust-stack/) | P6–P7（Axum・本番切替・Rails 削除） |

## コマンド

```bash
./scripts/sync-lib-domain-rust-tracking.sh
.cursor/skills/test-common/scripts/run-test-rust-domain.sh
scripts/run-rust-contract-tests.sh
```

## 関連

- 規約: [`ARCHITECTURE.md`](../../../ARCHITECTURE.md)
- Gateway 境界: 同 ARCHITECTURE.md（`## What we require` / Gateway boundary）
