# Angular統合の機械的検証手順（ローカル）

## 再起動について

- **Rails**: 開発環境では `enable_reloading = true` のため、**コントローラ等の変更は再起動不要**。ファイル保存後に次リクエストで反映される。
- **Angular**: `ng serve` はファイル監視で自動リロードされる。

## 認証フロー確認（モックログイン）

### テストで確認
```bash
bin/rails test test/controllers/auth_test_controller_test.rb
```

- `test_mock_login_redirects_to_return_to_when_session_return_to_present`: モックログイン後に return_to（4200）へリダイレクトすることを検証
- `test_mock_login_redirects_to_root_when_no_return_to`: return_to 未設定時は root へリダイレクトすることを検証

### 手動確認
1. `http://localhost:4200` にアクセス
2. 「ログイン」リンクをクリック → `http://localhost:3000/auth/login?return_to=...` へ遷移
3. モックログイン（developer/farmer/researcher）をクリック
4. **期待**: `http://localhost:4200/` にリダイレクトされ、「ようこそ、...」が表示される

## 1. 起動準備

### Rails API
```bash
FRONTEND_URL=http://localhost:4200 bin/rails server -p 3000
```

### Angular
```bash
cd frontend
npm install
npm run start
```

## 2. API ルート整合（Rust スタック）

フロントの `/api/v1` パスが `agrr-server` に登録されているかを機械確認します。

```bash
scripts/verify-angular-api-rust-routing.sh
```

CORS・Cookie 認証は **§4 の手動スモーク**（ブラウザ）で確認します。

## 3. Angularビルド/起動確認

```bash
cd frontend
npm run build
```

## 4. 結合(E2E)スモークチェック（UI確認）

1. `http://localhost:4200` にアクセス
2. 未ログイン時に「ログインが必要です」が表示される
3. ログイン導線（`/auth/login`）が開く
4. ログイン後に「ようこそ、...」表示へ切り替わる
5. 「ログアウト」で未ログイン状態に戻る
