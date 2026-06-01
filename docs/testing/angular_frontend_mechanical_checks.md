# Angular統合の機械的検証手順（ローカル）

## 再起動について

- **Rails**: 開発環境では `enable_reloading = true` のため、**コントローラ等の変更は再起動不要**。ファイル保存後に次リクエストで反映される。
- **Angular**: `ng serve` はファイル監視で自動リロードされる。

## 認証フロー確認（モックログイン）

### テストで確認

```bash
# 推奨: E2E（/api/v1/auth/me はモックしない）
cd frontend && npm run e2e:capture-for-agent   # 要 dev-docker + ng serve（スキル参照）

# または R4 一式
scripts/run-rust-contract-tests.sh
```

- **`GET /api/v1/auth/me`**: `crates/agrr-server/src/auth_api.rs`。Ruby 契約は P8.6 で削除済み（E2E で回帰）
- 開発用 `GET /auth/test/*`: `crates/agrr-server/src/auth_test.rs`

### 手動確認
1. `http://localhost:4200` にアクセス
2. 「ログイン」リンクをクリック → `http://localhost:4200/login?return_to=...` へ遷移（SPA 内）
3. モックログイン（developer/farmer/researcher）をクリック
4. **期待**: `http://localhost:4200/` にリダイレクトされ、「ようこそ、...」が表示される

## 1. 起動準備

### API（Rust）
```bash
.cursor/skills/dev-docker/scripts/up.sh   # :3000 strangler → agrr-server
cd frontend && ng serve --host 127.0.0.1
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
3. ログイン画面（`/login`）が開く
4. ログイン後に「ようこそ、...」表示へ切り替わる
5. 「ログアウト」で未ログイン状態に戻る
