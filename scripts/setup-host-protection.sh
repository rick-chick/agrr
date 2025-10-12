#!/bin/bash
# ホスト環境での保護機能セットアップスクリプト
# AGRRプロジェクトの開発DBを誤った操作から保護します

set -e

SHELL_RC=""
if [ -f "$HOME/.bashrc" ]; then
  SHELL_RC="$HOME/.bashrc"
elif [ -f "$HOME/.zshrc" ]; then
  SHELL_RC="$HOME/.zshrc"
else
  echo "❌ .bashrc or .zshrc not found"
  exit 1
fi

echo "🛡️  AGRR ホスト環境保護機能のセットアップ"
echo ""
echo "このスクリプトは以下を行います："
echo "1. PREVENT_TEST_IN_DEV環境変数の設定"
echo "2. railsコマンドのエイリアス設定（Docker強制）"
echo "3. テスト実行エイリアスの追加"
echo ""

# 既に設定済みかチェック
if grep -q "AGRR Project Protection" "$SHELL_RC"; then
  echo "⚠️  既に保護機能が設定されています"
  echo "設定ファイル: $SHELL_RC"
  exit 0
fi

echo "設定ファイル: $SHELL_RC"
read -p "続行しますか？ (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ キャンセルしました"
  exit 1
fi

# 設定を追加
cat >> "$SHELL_RC" << 'EOF'

# ==========================================
# AGRR Project Protection
# ==========================================
# ホスト環境でのrails/rakeコマンド直接実行を防止

# AGRR プロジェクトディレクトリを検出
agrr_check_dir() {
  if [[ "$(pwd)" =~ "agrr" ]] || [[ "$(pwd)" =~ "AGRR" ]]; then
    return 0
  fi
  return 1
}

# PREVENT_TEST_IN_DEV を常に設定（AGRRプロジェクト内）
if agrr_check_dir; then
  export PREVENT_TEST_IN_DEV=true
fi

# railsコマンドのラッパー関数
rails() {
  if agrr_check_dir; then
    echo "⚠️  ホスト環境でのrailsコマンド実行は推奨されません"
    echo ""
    echo "✅ 代わりに以下を使用してください："
    echo "   docker compose exec web bundle exec rails $@"
    echo ""
    read -p "それでも実行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi
  command rails "$@"
}

# rakeコマンドのラッパー関数
rake() {
  if agrr_check_dir; then
    echo "⚠️  ホスト環境でのrakeコマンド実行は推奨されません"
    echo ""
    echo "✅ 代わりに以下を使用してください："
    echo "   docker compose exec web bundle exec rake $@"
    echo ""
    read -p "それでも実行しますか？ (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi
  command rake "$@"
}

# AGRRプロジェクト用のエイリアス
if agrr_check_dir; then
  alias agrr-test='docker compose run --rm test bundle exec rails test'
  alias agrr-rails='docker compose exec web bundle exec rails'
  alias agrr-rake='docker compose exec web bundle exec rake'
  alias agrr-console='docker compose exec web bundle exec rails console'
fi

# ==========================================
# End of AGRR Project Protection
# ==========================================
EOF

echo ""
echo "✅ 保護機能の設定が完了しました"
echo ""
echo "以下のコマンドで設定を有効化してください："
echo "  source $SHELL_RC"
echo ""
echo "または、ターミナルを再起動してください"
echo ""
echo "📝 追加されたエイリアス："
echo "  agrr-test    - テスト実行（Docker）"
echo "  agrr-rails   - railsコマンド（Docker）"
echo "  agrr-rake    - rakeコマンド（Docker）"
echo "  agrr-console - Railsコンソール（Docker）"

