#!/bin/bash
# 作物追加時の二重リクエスト検証スクリプト

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 作物追加時の二重リクエスト検証"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 色定義
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Dockerが起動しているか確認
if ! docker compose ps | grep -q "web.*Up"; then
    echo -e "${RED}❌ Dockerコンテナが起動していません${NC}"
    echo "以下のコマンドで起動してください:"
    echo "  docker compose up -d"
    exit 1
fi

echo -e "${GREEN}✅ Dockerコンテナは起動中です${NC}"
echo ""

# JavaScriptファイルが存在するか確認
JS_FILE="app/assets/javascripts/crop_palette_drag.js"
if [ ! -f "$JS_FILE" ]; then
    echo -e "${RED}❌ $JS_FILE が見つかりません${NC}"
    exit 1
fi

echo -e "${GREEN}✅ JavaScriptファイルが存在します${NC}"
echo ""

# 修正が適用されているか確認
echo -e "${BLUE}📝 修正内容を確認中...${NC}"

# 1. イベントリスナーの重複登録防止
if grep -q "dataset.dragInitialized === 'true'" "$JS_FILE"; then
    echo -e "${GREEN}  ✅ イベントリスナーの重複登録防止が実装されています${NC}"
else
    echo -e "${RED}  ❌ イベントリスナーの重複登録防止が見つかりません${NC}"
fi

# 2. リクエストの二重送信防止
if grep -q "let isAddingCrop = false" "$JS_FILE"; then
    echo -e "${GREEN}  ✅ リクエストの二重送信防止が実装されています${NC}"
else
    echo -e "${RED}  ❌ リクエストの二重送信防止が見つかりません${NC}"
fi

# 3. デバッグログ
if grep -q "DUPLICATE REQUEST BLOCKED" "$JS_FILE"; then
    echo -e "${GREEN}  ✅ デバッグログが実装されています${NC}"
else
    echo -e "${RED}  ❌ デバッグログが見つかりません${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📋 次のステップ${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. ブラウザで動作確認:"
echo "   a) http://localhost:3000 にアクセス"
echo "   b) 作付け計画の結果ページを開く"
echo "   c) F12で開発者ツールを開く"
echo "   d) Consoleタブで以下のログを確認:"
echo ""
echo -e "${YELLOW}      期待されるログ:${NC}"
echo "      🎯 [DRAG START] mousedownイベント発火"
echo "      🏁 [DRAG END] mouseupイベント発火"
echo "      📍 [DROP] ドロップ位置計算"
echo "      🚀 [ADD CROP] 関数呼び出し開始"
echo "      🔒 [LOCK] リクエスト中フラグを設定"
echo "      📤 [REQUEST] 作物追加リクエスト送信"
echo "      📥 [RESPONSE] レスポンス受信"
echo "      🔓 [UNLOCK] リクエスト中フラグを解除"
echo ""
echo -e "${YELLOW}      二重リクエストがブロックされた場合:${NC}"
echo "      ⚠️  [DUPLICATE REQUEST BLOCKED] 既にリクエスト処理中です"
echo ""
echo "2. Networkタブで確認:"
echo "   a) Networkタブを開く"
echo "   b) 'add_crop'でフィルター"
echo "   c) リクエストが1回のみか確認"
echo ""
echo "3. 詳細なガイド:"
echo "   docs/DUPLICATE_REQUEST_CHECK.md を参照"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✨ 準備完了！ブラウザで検証を開始してください${NC}"
echo ""

