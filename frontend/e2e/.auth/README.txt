認証付き Playwright storage state（任意）

## 自動（Agent キャプチャ・development のみ）

`npm run e2e:capture-for-agent` を実行すると Playwright が次を行う。

1. `RAILS_ENV=development` の Rails（127.0.0.1:3000）と ng（127.0.0.1:4200）を起動（または既存を再利用）
2. global setup が同じパスを **`APIRequestContext` + `maxRedirects: 0`** で叩き、**302 の `Set-Cookie`** からセッションを取得（**locale プレフィックスは付けない**。フロント表示を待たないため `FRONTEND_URL` と return_to の食い違いでリダイレクト先が変わっても Cookie は付く）
3. **`e2e/.auth/dev-session.json`** を書き出し、キャプチャテストで共有

OAuth は不要。`dev-session.json` は秘密を含むため **コミットしない**（.gitignore 済み）。

## 手動（codegen・OAuth）

1. フロントと API が動く環境で一度ログインした状態を保存する。
   例: cd frontend && npx playwright codegen --save-storage=e2e/.auth/state.json http://127.0.0.1:4200/
   OAuth 完了後ブラウザを閉じると state.json ができる。

2. または既存の state を PLAYWRIGHT_STORAGE_STATE に渡す。
   PLAYWRIGHT_STORAGE_STATE=/path/to/state.json npm run test:e2e

`state.json` は秘密を含むためコミットしない。.gitignore 済み。
