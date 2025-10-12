#!/bin/bash
# agrrコマンドのデバッグ用スクリプト

set -e

echo "🔍 AGRR デバッグスクリプト"
echo "================================"

# デフォルト値
LATITUDE=${1:-35.68}
LONGITUDE=${2:-139.77}
START_DATE=${3:-2024-01-01}
END_DATE=${4:-2024-01-31}

echo "📍 Location: ${LATITUDE}, ${LONGITUDE}"
echo "📅 Period: ${START_DATE} to ${END_DATE}"
echo ""

# agrrコマンドのパスを取得
if [ -f "lib/core/agrr" ]; then
    AGRR_PATH="lib/core/agrr"
elif [ -f "/app/lib/core/agrr" ]; then
    AGRR_PATH="/app/lib/core/agrr"
else
    echo "❌ Error: agrr command not found"
    exit 1
fi

echo "🔧 AGRR Path: ${AGRR_PATH}"
echo ""

# agrrコマンドのバージョン確認
echo "📦 AGRR Version:"
${AGRR_PATH} --version || echo "  (version command not available)"
echo ""

# 天気データを取得
echo "🌤️  Fetching weather data..."
echo "Command: ${AGRR_PATH} weather --location ${LATITUDE},${LONGITUDE} --start-date ${START_DATE} --end-date ${END_DATE} --json"
echo ""

OUTPUT=$(${AGRR_PATH} weather \
  --location "${LATITUDE},${LONGITUDE}" \
  --start-date "${START_DATE}" \
  --end-date "${END_DATE}" \
  --json)

# 結果を整形して表示
echo "📥 Raw Output (first 1000 chars):"
echo "${OUTPUT}" | head -c 1000
echo ""
echo ""

# JSONをパースして表示
echo "📊 Parsed Data:"
echo "${OUTPUT}" | python3 -m json.tool 2>/dev/null | head -n 50 || echo "  (failed to parse JSON)"
echo ""

# データカウント
DATA_COUNT=$(echo "${OUTPUT}" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('data', {}).get('data', [])))" 2>/dev/null || echo "0")
echo "📈 Total records: ${DATA_COUNT}"

# サンプルデータ表示
echo ""
echo "📝 Sample Data (first 3 records):"
echo "${OUTPUT}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
records = data.get('data', {}).get('data', [])
for i, record in enumerate(records[:3]):
    print(f'  #{i+1}: {record.get(\"time\")} - Temp: {record.get(\"temperature_2m_min\")}~{record.get(\"temperature_2m_max\")}°C, Precip: {record.get(\"precipitation_sum\")}mm')
" 2>/dev/null || echo "  (failed to extract sample data)"

echo ""
echo "✅ Debug complete"

