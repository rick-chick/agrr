Agent レビュー用スクリーンショット（`e2e/agent-review/out/`）

## 事前準備（全ルートを漏れなく撮る）

1. **必読**: `route-to-png.md`（`npm run e2e:manifest` で `route-manifest.json` と同時更新）
   - 各 `pattern` の E2E URL と **`out/{ベース}.{ja|en|in}.png`** が対応表になっている。Agent はユーザーに URL を聞かずここを正とする。
2. **キャプチャ** … **`npm run e2e:capture-for-agent`** のみ。**development** の `AuthTestController` モックログインで `127.0.0.1:3000` にセッションを付与し、Angular は `127.0.0.1:4200`。`/api/v1/auth/me` はモックしない。DB・Rails 起動が必要。`e2e/.auth/dev-session.json` は Playwright globalSetup が自動生成（gitignore）。**実行時**に `e2e/resolve-capture-urls.ts` が一覧 API から **実在 id** を取り、マニフェストの placeholder `1` を差し替える（`route-to-png.md` の URL 列は代表値のまま）。**`login` は未ログイン storageState の `login-capture-for-agent.spec.ts` が別途撮影**（`auth/login` は SPA リダイレクトのためマニフェスト対象外）（dev-session 付き spec では skip）。**Playwright は `E2E_CAPTURE_DEV_SESSION=1` のときワーカー数 1**（ホーム等の `fullPage` スクリーンショットの Chrome プロトコルエラー回避）。
3. コマンド終了時に **件数検証**（`verify-capture-complete.mjs`）に通らないと失敗で終了する。
4. **手動 OAuth** で保存したい場合は **`e2e/.auth/README.txt`**（`state.json`）を参照。

## 生成

```bash
cd frontend
npm run e2e:manifest   # ルート変更時
npm run e2e:capture-for-agent
# または npm run test:e2e（キャプチャ spec は未設定時 skip）
```

出力: `out/{ベース}.ja.png` / `{ベース}.en.png` / `{ベース}.in.png`（各ルート 3 言語・.gitignore・再実行で上書き）

## Cursor でのレビュー（正規ルート）

**スキル**: **`frontend-agent-visual-review`**（必須出力: `e2e/agent-review/visual-review-results.md` … サマリ表で pattern ごとに ja/en/in の 3 枚を見てレイアウトと **i18n** を指摘）

**i18n**: 各 pattern で `.en.png` は英語、`.in.png` はヒンディー（インド向け）であること。未翻訳キー・日本語残り・`%{...}` 残りは **`frontend-agent-visual-review`** の「言語・i18n」節に従い指摘する。機械検出は `npm run check-hardcoded-i18n`。

1. **`@frontend/e2e/agent-review/out`** でフォルダごと参照する（**気になる枚だけ拾うのは補助**。フルレビューはフォルダ＋下記バッチ）。
2. 同時に **`@frontend/e2e/agent-review/route-to-png.md`** と **`@frontend/e2e/route-manifest.json`** を添える。
3. **バッチ分割**（注意幅の都合）: `route-to-png.md` の表を **先頭から 10〜15 行程度**ずつ区切り、各バッチで「このバッチに対応する `out/` 内のファイル名」をレビューさせる。最後まで連番で繰り返し、**成果物 1 ファイルにマージ**する。
4. プロンプト例:

「`frontend-agent-visual-review` に従い、`route-to-png.md` のこのバッチ（行 ○〜○）について各 pattern の **ja / en / in** PNG をレビューし、`visual-review-results.md` にサマリ表（**i18n 列**含む）を追記してください。CSS 直書きの列挙はせず `audit:css-tokens` を正と書いてください。」

## 監査（別コマンド）

CSS トークン当て漏れの列挙: `npm run audit:css-tokens`
