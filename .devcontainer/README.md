# Dev Container 環境

このプロジェクトは **Dev Containers** と **GitHub Codespaces** をサポートしています。

## 🚀 推奨される開発方法（2025年）

### 方法1: GitHub Codespaces（最も簡単）⭐

1. GitHubリポジトリページで **Code** → **Codespaces** → **Create codespace**
2. ブラウザで自動的に開発環境が起動
3. ターミナルで即座にテスト実行可能

```bash
bundle exec rails test
```

**メリット:**
- インストール不要
- どのOSからでもアクセス可能
- 月60時間まで無料

### 方法2: VS Code + Dev Containers

1. **必要なもの:**
   - Docker Desktop
   - Visual Studio Code
   - Dev Containers拡張機能

2. **手順:**
   ```
   1. VSCodeでプロジェクトを開く
   2. コマンドパレット(F1) → "Dev Containers: Reopen in Container"
   3. 自動的にコンテナがビルド・起動
   ```

3. **テスト実行:**
   ```bash
   bundle exec rails test
   ```

### 方法3: Docker Compose（CI/CD・本番想定）

```bash
# イメージビルド
docker-compose -f .devcontainer/docker-compose.yml build

# コンテナ起動
docker-compose -f .devcontainer/docker-compose.yml up -d

# テスト実行
docker-compose -f .devcontainer/docker-compose.yml exec app bundle exec rails test

# 停止
docker-compose -f .devcontainer/docker-compose.yml down
```

## ✅ 環境に含まれるもの

- Ruby 3.3.x
- Rails 8.0.x
- SQLite 3.x
- Node.js (LTS)
- Git
- GitHub CLI

## 🧪 テストの実行

### 全テストを実行
```bash
bundle exec rails test
```

### 特定のテストを実行
```bash
bundle exec rails test test/controllers/api/v1/base_controller_test.rb
```

### システムテストを実行
```bash
bundle exec rails test:system
```

### カバレッジ付きで実行
```bash
COVERAGE=true bundle exec rails test
```

## 📝 開発フロー

1. **Dev Containerで開発**
   ```bash
   # サーバー起動
   rails server -b 0.0.0.0
   
   # テスト実行
   bundle exec rails test
   
   # コンソール
   rails console
   ```

2. **コミット前にテスト**
   ```bash
   bundle exec rails test
   ```

3. **プッシュ後に自動CI/CD**
   - GitHub Actionsが自動実行
   - 結果はGitHubのActionsタブで確認

## 🌐 ポート転送

- **3000**: Rails server
- 自動的にホストマシンにポート転送されます

## 🔧 トラブルシューティング

### コンテナのリビルド
```bash
# VSCode: コマンドパレット → "Dev Containers: Rebuild Container"
# または
docker-compose -f .devcontainer/docker-compose.yml build --no-cache
```

### 依存関係の再インストール
```bash
bundle install
```

### データベースのリセット
```bash
rails db:reset
```

## 📚 参考リンク

- [Dev Containers公式ドキュメント](https://code.visualstudio.com/docs/devcontainers/containers)
- [GitHub Codespaces](https://github.com/features/codespaces)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)





