# E2E smoke（Playwright + Angular + agrr-server）

正常系の**到達・読込完了・主要操作**を簡潔に検証する。ピクセル回帰は行わない。

## 前提

1. `bundle exec rails db:prepare`（`storage/development.sqlite3`）
2. 別ターミナル: リポジトリ root で `AGRR_RUST_API=1 ./scripts/e2e-strangler-stack.sh`
3. frontend で:

```bash
npm run test:e2e:smoke
```

`E2E_CAPTURE_DEV_SESSION=1` により globalSetup が Rust の `/auth/test/mock_login_as/developer` で `e2e/.auth/dev-session.json` を生成する。`E2E_STRANGLER=1` で Playwright は Rails を起動せず nginx :3000 → agrr-server :8080 を利用する。

## スペック

| ファイル | 内容 |
|----------|------|
| `route-smoke.spec.ts` | `route-manifest.json` 全ルート: 正しいホスト表示・ローディング解消・`.error-message` 非表示 |
| `operation-smoke.spec.ts` | ホーム CTA、ナビ、公開ウィザード、問い合わせ送信、マスタ CRUD 画面、ガント UI、API キー、天気、作業予定 D&D など |

`E2E_CAPTURE_DEV_SESSION` 未設定時は smoke は skip（`route-manifest-coverage` 等は `npm run test:e2e` で実行可）。未ログイン向けに `login` / 404 のみ別 describe で実行。
