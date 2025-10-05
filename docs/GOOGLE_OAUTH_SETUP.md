# Google OAuth 認証セットアップガイド

このガイドでは、AGRRアプリケーションでGoogle OAuth認証を設定する方法を説明します。

## 🔐 セキュリティ重視の設計

この実装は以下のセキュリティ対策を含んでいます：

- **CSRF保護**: `omniauth-rails_csrf_protection`を使用
- **セキュアなセッション管理**: 独自のセッションテーブル
- **セッションID検証**: フォーマット検証と期限管理
- **HTTPS強制**: 本番環境でのSSL/TLS
- **レート制限**: 認証試行の制限
- **Content Security Policy**: XSS攻撃の防止
- **セキュアクッキー**: HttpOnly、Secure、SameSite属性

## 📋 前提条件

1. Google Cloud Console アカウント
2. Rails 8.0+ アプリケーション
3. 環境変数の設定

## 🚀 セットアップ手順

### 0. 前提条件の確認

この実装はDocker環境で動作確認されています：

- **Docker & Docker Compose** (推奨)
- Ruby 3.3.9+
- Rails 8.0+
- SQLite 3.8.0+

#### Docker環境での開発（推奨）

Dockerを使用することで、環境の違いによる問題を回避できます。

### 1. Google Cloud Console での設定

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを作成または既存のプロジェクトを選択
3. **APIs & Services** > **Credentials** に移動
4. **Create Credentials** > **OAuth 2.0 Client IDs** を選択
5. アプリケーションタイプを **Web application** に設定
6. 承認済みのリダイレクトURIを追加：
   ```
   http://localhost:3000/auth/google_oauth2/callback  # 開発環境
   https://your-domain.com/auth/google_oauth2/callback # 本番環境
   ```
7. クライアントIDとクライアントシークレットを取得

### 2. Docker環境の準備

#### Docker Desktopの起動
```bash
# Docker Desktopが起動していることを確認
docker --version
docker-compose --version
```

#### 環境変数の設定
`.env` ファイルを作成して以下を追加：

```bash
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_google_client_id_here
GOOGLE_CLIENT_SECRET=your_google_client_secret_here

# Rails Configuration
RAILS_ENV=development
RAILS_MASTER_KEY=your_master_key_here
```

### 3. Dockerコンテナのビルドと起動

```bash
# Dockerイメージのビルド
docker-compose build

# データベースマイグレーションの実行
docker-compose run --rm web rails db:migrate

# アプリケーションの起動
docker-compose up
```

### 4. 動作確認

1. ブラウザで `http://localhost:3000` にアクセス
2. ログインページが表示されることを確認
3. "Sign in with Google" ボタンが表示されることを確認

### 5. 開発コマンド

```bash
# コンテナ内でRailsコンソールを起動
docker-compose exec web rails console

# テストの実行
docker-compose run --rm web rails test

# 新しいマイグレーションの作成
docker-compose run --rm web rails generate migration CreateNewTable

# マイグレーションの実行
docker-compose run --rm web rails db:migrate

# データベースのリセット
docker-compose run --rm web rails db:reset

# コンテナの停止
docker-compose down
```

### トラブルシューティング

**Dockerデーモンが起動していない場合**
```bash
# Docker Desktopを起動
# または Linux環境の場合
sudo systemctl start docker
```

**ポートが使用中の場合**
```bash
# 使用中のポートを確認
lsof -i :3000

# docker-compose.ymlでポートを変更
# ports:
#   - "3001:3000"  # 3001ポートを使用
```

## 🔧 設定ファイル

### OmniAuth 設定 (`config/initializers/omniauth.rb`)

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, 
    ENV['GOOGLE_CLIENT_ID'], 
    ENV['GOOGLE_CLIENT_SECRET'],
    {
      name: :google,
      scope: 'email,profile',
      prompt: 'select_account',
      access_type: 'offline',
      provider_ignores_state: false,
      skip_jwt: true
    }
end
```

### セキュリティ設定 (`config/initializers/security.rb`)

- HTTPS強制（本番環境）
- セキュアクッキー設定
- Content Security Policy
- レート制限

## 📊 データベース構造

### Users テーブル

```sql
CREATE TABLE users (
  id INTEGER PRIMARY KEY,
  email VARCHAR UNIQUE NOT NULL,
  name VARCHAR NOT NULL,
  google_id VARCHAR UNIQUE NOT NULL,
  avatar_url VARCHAR,
  created_at DATETIME,
  updated_at DATETIME
);
```

### Sessions テーブル

```sql
CREATE TABLE sessions (
  id INTEGER PRIMARY KEY,
  session_id VARCHAR UNIQUE NOT NULL,
  data TEXT,
  user_id INTEGER NOT NULL,
  expires_at DATETIME NOT NULL,
  created_at DATETIME,
  updated_at DATETIME,
  FOREIGN KEY (user_id) REFERENCES users (id)
);
```

## 🧪 テスト

### テストの実行

```bash
# 全テストの実行
rails test

# OAuth関連のテストのみ
rails test test/controllers/auth_controller_test.rb
rails test test/models/user_test.rb
rails test test/models/session_test.rb
rails test test/integration/oauth_integration_test.rb
```

### テストカバレッジ

- User モデルの検証
- Session モデルの管理
- OAuth フローの統合テスト
- セキュリティ対策のテスト

## 🔒 セキュリティ機能

### 1. セッション管理

- 32バイトのランダムセッションID
- 2週間の有効期限
- 自動期限延長
- 期限切れセッションの自動クリーンアップ

### 2. CSRF保護

- OmniAuth Rails CSRF Protection
- 状態パラメータの検証
- トークンベースの保護

### 3. 入力検証

- メールアドレス形式の検証
- セッションID形式の検証
- XSS攻撃の防止

### 4. レート制限

```ruby
# 認証エンドポイント: 5回/分
Rack::Attack.throttle('auth/ip', limit: 5, period: 1.minute)

# API エンドポイント: 100回/分
Rack::Attack.throttle('api/ip', limit: 100, period: 1.minute)
```

## 🚨 トラブルシューティング

### よくある問題

1. **OAuth リダイレクトエラー**
   - Google Cloud Console のリダイレクトURI設定を確認
   - 環境変数の設定を確認

2. **セッションが保存されない**
   - クッキーの設定を確認
   - データベース接続を確認

3. **CSRF エラー**
   - `omniauth-rails_csrf_protection` の設定を確認
   - トークンの有効性を確認

### ログの確認

```bash
# Rails ログの確認
tail -f log/development.log

# エラーログの確認
grep "ERROR" log/development.log
```

## 📚 API エンドポイント

### 認証エンドポイント

```
GET  /auth/login                    # ログインページ
GET  /auth/google_oauth2           # Google OAuth 開始
GET  /auth/google_oauth2/callback  # OAuth コールバック
GET  /auth/failure                 # 認証失敗
DELETE /auth/logout                # ログアウト
```

### 保護されたエンドポイント

```
GET    /api/v1/files              # ファイル一覧（認証必要）
POST   /api/v1/files              # ファイルアップロード（認証必要）
GET    /api/v1/files/:id          # ファイル詳細（認証必要）
DELETE /api/v1/files/:id          # ファイル削除（認証必要）
```

### 公開エンドポイント

```
GET    /api/v1/health             # ヘルスチェック（認証不要）
```

## 🔄 セッション管理

### セッションの作成

```ruby
user = User.from_omniauth(auth_hash)
session = Session.create_for_user(user)
```

### セッションの検証

```ruby
session = Session.active.find_by(session_id: session_id)
if session && !session.expired?
  current_user = session.user
end
```

### セッションのクリーンアップ

```bash
# 期限切れセッションの削除
rails sessions:cleanup

# セッション統計の表示
rails sessions:stats
```

## 🚀 本番環境での考慮事項

1. **HTTPS の強制**
   - SSL証明書の設定
   - セキュアクッキーの有効化

2. **環境変数**
   - 本番環境での適切な設定
   - シークレットの管理

3. **ログ管理**
   - セキュリティイベントのログ
   - 監査ログの実装

4. **監視**
   - 認証失敗の監視
   - 異常なアクセスパターンの検出

## 📖 参考資料

- [OmniAuth Documentation](https://github.com/omniauth/omniauth)
- [Google OAuth 2.0 Documentation](https://developers.google.com/identity/protocols/oauth2)
- [Rails Security Guide](https://guides.rubyonrails.org/security.html)
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)

## ✅ 実装完了確認

以下のファイルが正常に作成されていることを確認してください：

### モデル
- `app/models/user.rb` - Userモデル
- `app/models/session.rb` - Sessionモデル

### コントローラー
- `app/controllers/auth_controller.rb` - OAuth認証コントローラー
- `app/controllers/home_controller.rb` - ダッシュボードコントローラー
- `app/controllers/application_controller.rb` - 認証機能付きベースコントローラー

### ビュー
- `app/views/auth/login.html.erb` - ログインページ
- `app/views/home/index.html.erb` - ダッシュボード

### 設定ファイル
- `config/initializers/omniauth.rb` - OmniAuth設定
- `config/initializers/security.rb` - セキュリティ設定
- `config/routes.rb` - ルーティング設定

### データベース
- `db/migrate/20250101000001_create_users.rb` - Usersテーブル
- `db/migrate/20250101000002_create_sessions.rb` - Sessionsテーブル

### テスト
- `test/models/user_test.rb` - Userモデルテスト
- `test/models/session_test.rb` - Sessionモデルテスト
- `test/controllers/auth_controller_test.rb` - 認証コントローラーテスト
- `test/controllers/security_test.rb` - セキュリティテスト
- `test/integration/oauth_integration_test.rb` - 統合テスト

## 🚀 次のステップ（Docker環境）

### 1. Docker Desktopの起動確認
```bash
# Docker Desktopが起動していることを確認
docker --version
docker-compose --version
```

### 2. Google Cloud Console での設定
1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. OAuth 2.0 クライアントIDの作成
3. リダイレクトURIの設定: `http://localhost:3000/auth/google_oauth2/callback`

### 3. 環境変数の設定
`.env` ファイルを作成：
```bash
# Google OAuth Configuration
GOOGLE_CLIENT_ID=your_actual_google_client_id
GOOGLE_CLIENT_SECRET=your_actual_google_client_secret

# Rails Configuration
RAILS_ENV=development
RAILS_MASTER_KEY=your_master_key_here
```

### 4. Dockerコンテナのビルドと起動
```bash
# Dockerイメージのビルド
docker-compose build

# データベースマイグレーションの実行
docker-compose run --rm web rails db:migrate

# アプリケーションの起動
docker-compose up
```

### 5. 動作確認
1. ブラウザで `http://localhost:3000` にアクセス
2. ログインページが表示されることを確認
3. "Sign in with Google" ボタンをクリックしてOAuth認証をテスト

### 6. テストの実行
```bash
# 全テストの実行
docker-compose run --rm web rails test

# 特定のテストの実行
docker-compose run --rm web rails test test/models/user_test.rb
```

### 7. 開発の継続
```bash
# コンテナ内でRailsコンソール
docker-compose exec web rails console

# ログの確認
docker-compose logs -f web

# コンテナの再起動
docker-compose restart
```

## 🤝 サポート

問題が発生した場合は、以下を確認してください：

1. ログファイルの確認
2. 環境変数の設定
3. Google Cloud Console の設定
4. ネットワーク接続

追加のサポートが必要な場合は、プロジェクトのIssueページで質問してください。
