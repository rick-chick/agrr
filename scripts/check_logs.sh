#!/bin/bash
# ログ確認用スクリプト

echo "📋 AGRR ログチェッカー"
echo "================================"
echo ""

# ログファイルのパスを確認
if [ -f "log/development.log" ]; then
    LOG_FILE="log/development.log"
elif [ -f "/app/log/development.log" ]; then
    LOG_FILE="/app/log/development.log"
else
    echo "❌ Error: Log file not found"
    exit 1
fi

echo "📁 Log file: ${LOG_FILE}"
echo ""

# 最近のagrrコマンド実行ログ
echo "🔧 Recent AGRR Commands:"
echo "================================"
tail -n 1000 "${LOG_FILE}" | grep "\[AGRR Command\]" | tail -n 5
echo ""

# agrrコマンドのエラーログ
echo "❌ AGRR Errors (last 5):"
echo "================================"
ERROR_COUNT=$(tail -n 1000 "${LOG_FILE}" 2>/dev/null | grep -c "\[AGRR Error\]" 2>/dev/null || echo "0")
ERROR_COUNT=$(echo "$ERROR_COUNT" | head -n1 | tr -d '[:space:]')
if [ "$ERROR_COUNT" -gt 0 ]; then
    tail -n 1000 "${LOG_FILE}" | grep "\[AGRR Error\]" -A 2 | tail -n 15
else
    echo "  No errors found ✅"
fi
echo ""

# データ保存のサマリー
echo "💾 Weather Data Save Summary (last 5):"
echo "================================"
tail -n 1000 "${LOG_FILE}" | grep "\[Weather Data Summary\]" | tail -n 5
echo ""

# 進捗状況
echo "📊 Progress Updates (last 5):"
echo "================================"
tail -n 1000 "${LOG_FILE}" | grep "Progress:" | tail -n 5
echo ""

# 最近のエラー全般
echo "⚠️  Recent Errors (last 10):"
echo "================================"
tail -n 500 "${LOG_FILE}" | grep -E "(ERROR|Error|error|❌)" | tail -n 10 || echo "  No errors found ✅"
echo ""

echo "✅ Log check complete"
echo ""
echo "💡 Tips:"
echo "  - すべてのログを見るには: tail -f ${LOG_FILE}"
echo "  - agrrログのみ: tail -f ${LOG_FILE} | grep -E '(AGRR|Weather|💾|📊|🔧)'"
echo "  - エラーのみ: tail -f ${LOG_FILE} | grep -E '(ERROR|Error|❌)'"

