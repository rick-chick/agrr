認証付き Playwright storage state（任意）

## 自動（Agent キャプチャ・development のみ）

モックログインは **Rails ではなく agrr-server（Rust）** が処理する。
ng serve（127.0.0.1:4200）proxy → nginx strangler（127.0.0.1:3000）→ agrr-server（127.0.0.1:8080）の `/auth/test/mock_login_as/{user}`。

### 事前起動（推奨）

```bash
# リポジトリ root
.cursor/skills/dev-docker/scripts/host-rust-stack.sh
```

失敗したとき: `cargo build -p agrr-server --release` のあと `.cursor/skills/dev-docker/scripts/host-rust-stack.sh stop` → 再起動。
nginx 設定を変えたら `nginx -s reload -c docker/nginx-strangler-host.conf`（または stack スクリプトで stop/start）。

### キャプチャ

```bash
cd frontend && npm run e2e:capture-for-agent
```

Playwright は `E2E_STRANGLER=1` のとき **Rails を起動しない**（:3000 は strangler 専用）。
`E2E_API_ORIGIN` 既定は `http://127.0.0.1:4200`（ng proxy 経由）。

1. ng（127.0.0.1:4200）を起動（または既存を再利用）
2. global setup が **`APIRequestContext` + `maxRedirects: 0`** で mock login を叩き、**302/303/307 の `Set-Cookie: session_id`** からセッションを取得（locale プレフィックスは付けない）
3. **`e2e/.auth/dev-session.json`** を書き出し、キャプチャテストで共有

OAuth は不要。`dev-session.json` は秘密を含むため **コミットしない**（.gitignore 済み）。

### 動作確認（curl）

```bash
curl -sI "http://127.0.0.1:4200/auth/test/mock_login_as/developer?return_to=http://127.0.0.1:4200/"
# 期待: HTTP/1.1 302|303|307 + set-cookie: session_id=...; SameSite=Lax
```

## ブラウザでの開発用ログイン（Angular :4200）

**開発ビルド**（`ng serve`）の `/login` にモックログイン欄が出る（本番ビルドでは非表示）。

1. リポジトリ root で `.cursor/skills/dev-docker/scripts/host-rust-stack.sh`（:3000 → agrr-server :8080）
2. Angular: `cd frontend && npm start`（既定 http://127.0.0.1:4200）
3. http://127.0.0.1:4200/login を開き、「開発者 / 農家 / 研究員」いずれかをクリック
4. API・認証は同一オリジン（proxy）。リダイレクト後 `GET /api/v1/auth/me` でユーザーが返ること

Google OAuth の redirect URI は **FRONTEND_URL 先頭 + `/auth/google_oauth2/callback`**（例: `http://127.0.0.1:4200/...`）。Google Console に登録すること。

E2E の global setup と同じ `/auth/test/mock_login_as/{user}?return_to=` 経路。

## Lighthouse CI（認証後代表ルート）

認証後 SPA ルート（`/plans`, `/plans/:id`, `/work`）はプリレンダ不可のため、**mock_login + cookie 注入**で計測する（E2E と同経路）。

```bash
# CI と同条件（Docker dev stack + build + lhci）
bash scripts/run-lighthouse-ci.sh

# 公開ルートのみ（Docker 不要）
bash scripts/run-lighthouse-ci.sh --public-only
```

手順:
1. `docker compose` で agrr-server + strangler を起動（`run-lighthouse-ci.sh` が自動実行）
2. `node frontend/scripts/lighthouse-ci-auth-setup.mjs` が `session_id` cookie と解決済み URL を `frontend/scripts/lighthouse-ci-auth-urls.json` に書き出す
3. `lighthouserc.js` が ng serve + `lighthouse-ci-auth-puppeteer.cjs` で cookie を注入して Lighthouse 計測

生成物（`.lighthouse-auth-cookies.json`, `lighthouse-ci-auth-urls.json`）は gitignore 済み。

## 手動（codegen・OAuth）

1. フロントと API が動く環境で一度ログインした状態を保存する。
   例: cd frontend && npx playwright codegen --save-storage=e2e/.auth/state.json http://127.0.0.1:4200/
   OAuth 完了後ブラウザを閉じると state.json ができる。

2. または既存の state を PLAYWRIGHT_STORAGE_STATE に渡す。
   PLAYWRIGHT_STORAGE_STATE=/path/to/state.json npm run test:e2e

`state.json` は秘密を含むためコミットしない。.gitignore 済み。
