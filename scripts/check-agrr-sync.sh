#!/bin/bash
# agrrバイナリの同期状態を確認するスクリプト

set -e

echo "========================================="
echo "AGRR Binary Sync Check"
echo "========================================="
echo ""

# ローカルのagrrバイナリを確認
if [ -f "lib/core/agrr" ]; then
    LOCAL_MD5=$(md5sum lib/core/agrr | cut -d' ' -f1)
    LOCAL_SIZE=$(du -h lib/core/agrr | cut -f1)
    LOCAL_DATE=$(stat -c %y lib/core/agrr | cut -d. -f1)
    
    echo "📂 Local binary (lib/core/agrr):"
    echo "   MD5:      $LOCAL_MD5"
    echo "   Size:     $LOCAL_SIZE"
    echo "   Modified: $LOCAL_DATE"
else
    echo "❌ Local binary not found: lib/core/agrr"
    echo ""
    echo "Build it with:"
    echo "  cd lib/core/agrr_core"
    echo "  ./build_standalone.sh --onefile"
    echo "  cp dist/agrr ../agrr"
    exit 1
fi

echo ""

# コンテナ内のagrrバイナリを確認
if docker compose ps | grep -q "web.*Up"; then
    CONTAINER_MD5=$(docker compose exec web md5sum /app/lib/core/agrr 2>/dev/null | cut -d' ' -f1 || echo "ERROR")
    
    if [ "$CONTAINER_MD5" = "ERROR" ]; then
        echo "❌ Container binary not accessible"
        echo "   Is the container running?"
        exit 1
    fi
    
    CONTAINER_SIZE=$(docker compose exec web du -h /app/lib/core/agrr 2>/dev/null | cut -f1 || echo "?")
    CONTAINER_DATE=$(docker compose exec web stat -c %y /app/lib/core/agrr 2>/dev/null | cut -d. -f1 || echo "?")
    
    echo "🐳 Container binary (/app/lib/core/agrr):"
    echo "   MD5:      $CONTAINER_MD5"
    echo "   Size:     $CONTAINER_SIZE"
    echo "   Modified: $CONTAINER_DATE"
    echo ""
    
    # MD5を比較
    if [ "$LOCAL_MD5" = "$CONTAINER_MD5" ]; then
        echo "✅ SYNCED: Local and container binaries are identical"
        echo "   Your local changes are being used in the container"
    else
        echo "❌ NOT SYNCED: Local and container binaries differ!"
        echo ""
        echo "This should not happen with volume mounts."
        echo "Try restarting the container:"
        echo "  docker compose restart web"
    fi
    
    echo ""
    
    # daemonステータスを確認
    echo "🔧 Daemon status:"
    DAEMON_STATUS=$(docker compose exec web /app/lib/core/agrr daemon status 2>&1 || echo "not running")
    echo "   $DAEMON_STATUS"
    
else
    echo "⚠️  Container is not running"
    echo "   Start it with: docker compose up"
fi

echo ""
echo "========================================="
echo "Quick commands:"
echo "========================================="
echo "# Start containers:"
echo "  docker compose up"
echo ""
echo "# Rebuild agrr binary:"
echo "  cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr"
echo ""
echo "# Check daemon status:"
echo "  docker compose exec web /app/lib/core/agrr daemon status"
echo ""
echo "# View startup logs:"
echo "  docker compose logs web | grep -A 10 'Configuring agrr'"
echo ""

