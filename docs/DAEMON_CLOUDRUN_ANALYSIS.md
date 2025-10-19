# agrr daemon機能のCloudRun/App Runner利用分析

## 概要

`lib/core/agrr`バイナリに追加されたdaemon機能について、CloudRun/App Runnerでの利用可能性を分析した結果をまとめます。

## daemon機能の詳細

### 仕組み
- UNIXソケット (`/tmp/agrr.sock`) を使用したデーモンプロセス
- Pythonインタープリターと必要なライブラリをメモリに常駐
- 起動時間を **4.8倍短縮** (2.4s → 0.5s)

### 使用方法
```bash
# daemon起動
agrr daemon start

# 状態確認
agrr daemon status

# 通常通りコマンド実行（自動的にdaemonを利用）
agrr weather --location 35.6762,139.6503 --days 7
agrr crop --query "tomato"

# daemon停止
agrr daemon stop
```

## CloudRun/App Runnerでの利用分析

### ❌ 推奨しない理由

#### 1. **ステートレス性との不整合**
- CloudRun/App Runnerはステートレスなコンテナ実行環境
- コンテナは**リクエストごとに起動/停止**される可能性がある
- daemonプロセスは永続的な状態を前提としており、設計思想が異なる

#### 2. **コールドスタート問題の根本解決にならない**
- コンテナ自体の起動時間は短縮できない
- 新しいコンテナインスタンスではdaemonも再起動が必要
- **初回リクエストでは効果なし**

#### 3. **リソース管理の複雑化**
- daemonプロセスが追加のメモリを消費
- CloudRun/App Runnerのメモリ制限に影響
- コスト増加の可能性

#### 4. **デバッグとモニタリングの困難さ**
- プロセス間通信（UNIXソケット）の監視が困難
- エラーハンドリングが複雑化
- ログの追跡が難しい

#### 5. **スケーリング時の問題**
- 複数コンテナインスタンスが起動する場合、各インスタンスで個別のdaemonが必要
- インスタンス間でdaemonを共有できない
- 水平スケーリングの効果が薄い

### ✅ **Litestreamパターンでの実装は可能**

**ご指摘の通り、litestreamと同様の方法で実装可能です！**

現在のプロジェクトでは `scripts/start_app.sh` でlitestreamをバックグラウンド起動しており、同じパターンでagrr daemonも起動できます。

#### 実装例（Litestreamパターン）

完全な実装は以下のファイルを参照：
- `Dockerfile.with-agrr-daemon`
- `scripts/start_app_with_agrr_daemon.sh`

**主なポイント**:

```bash
# scripts/start_app_with_agrr_daemon.sh (抜粋)

echo "Step 3: Starting agrr daemon..."
if [ -x "/usr/local/bin/agrr" ]; then
    /usr/local/bin/agrr daemon start
    if [ $? -eq 0 ]; then
        AGRR_DAEMON_PID=$(/usr/local/bin/agrr daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
        echo "✓ agrr daemon started (PID: $AGRR_DAEMON_PID)"
    fi
fi

# ... Litestream、Solid Queue、Rails起動 ...

# Cleanup時にdaemonも停止
cleanup() {
    echo "Shutting down services..."
    kill -TERM $RAILS_PID 2>/dev/null || true
    kill -TERM $SOLID_QUEUE_PID 2>/dev/null || true
    kill -TERM $LITESTREAM_PID 2>/dev/null || true
    
    # agrr daemonを停止
    /usr/local/bin/agrr daemon stop 2>/dev/null || true
    exit 0
}
```

```dockerfile
# Dockerfile.with-agrr-daemon (抜粋)

# agrr binaryをコピー
COPY lib/core/agrr /usr/local/bin/agrr
RUN chmod +x /usr/local/bin/agrr

# 起動スクリプトをコピー
COPY scripts/start_app_with_agrr_daemon.sh /app/scripts/
RUN chmod +x /app/scripts/start_app_with_agrr_daemon.sh

CMD ["/app/scripts/start_app_with_agrr_daemon.sh"]
```

### ⚠️ ただし効果は限定的

以下の条件を**すべて満たす**場合のみ効果があります：

1. **最小インスタンス数 ≥ 1** に設定（常時起動）
2. **リクエスト頻度が高い**（コンテナの再利用率が高い）
3. **同一コンテナで複数回実行**される

**効果が発揮される場面**:
- ✅ 2回目以降のリクエスト（同一コンテナ内）: 0.5s起動
- ❌ 新しいコンテナの初回リクエスト: 2.4s起動 + daemon起動オーバーヘッド

**コスト**:
- メモリ消費: +100-200MB
- コンテナ起動時間: +0.5-1.0s（daemon起動分）
- ディスク使用量: +113MB（agrr binary）

## 推奨される代替アプローチ

### ✅ 1. **非同期ジョブとして実行**
```ruby
# app/jobs/weather_fetch_job.rb
class WeatherFetchJob < ApplicationJob
  queue_as :default

  def perform(location, days)
    # agrrコマンドを非同期で実行
    result = `agrr weather --location #{location} --days #{days} --json`
    JSON.parse(result)
  end
end

# コントローラーから
WeatherFetchJob.perform_later(params[:location], params[:days])
```

**利点**:
- Railsの非同期処理機構を活用
- リクエストのブロッキングを回避
- エラーハンドリングが容易

### ✅ 2. **キャッシュの活用**
```ruby
# app/services/weather_service.rb
class WeatherService
  def self.fetch_weather(location, days)
    cache_key = "weather:#{location}:#{days}"
    
    Rails.cache.fetch(cache_key, expires_in: 1.hour) do
      result = `agrr weather --location #{location} --days #{days} --json`
      JSON.parse(result)
    end
  end
end
```

**利点**:
- 同じリクエストは再実行不要
- CloudRun/App RunnerでRedisなどを使用可能
- コスト削減

### ✅ 3. **最小インスタンス数の設定**
```bash
# Cloud Runの場合
gcloud run services update agrr-app \
  --min-instances=1 \
  --max-instances=10

# App Runnerの場合（apprunner.yaml）
InstanceConfiguration:
  Cpu: 1024
  Memory: 2048
  AutoScalingConfiguration:
    MinSize: 1
    MaxSize: 10
```

**利点**:
- コールドスタート自体を削減
- コンテナの再利用率が向上
- daemon有無に関わらず効果的

### ✅ 4. **agrrをライブラリとして利用**
```ruby
# Gemfile
gem 'agrr_core', path: 'lib/core/agrr_core'

# app/services/agrr_service.rb
require 'agrr_core'

class AgrrService
  def self.fetch_weather(location, days)
    # Pythonバイナリではなく、Rubyから直接呼び出し
    # (agrr_coreがRuby bindingを提供している場合)
    AgrrCore::Weather.fetch(location, days)
  end
end
```

**利点**:
- プロセス間通信のオーバーヘッドがない
- メモリ共有が効率的
- デバッグが容易

**注意**: agrr_coreがRuby bindingを提供している必要があります

### ✅ 5. **専用マイクロサービス化**
```
┌─────────────────┐
│  Rails App      │
│  (CloudRun)     │
└────────┬────────┘
         │ HTTP API
         ▼
┌─────────────────┐
│  agrr Service   │
│  (CloudRun)     │
│  + daemon常駐   │
└─────────────────┘
```

agrrを専用のHTTP APIサービスとして分離し、そちらでdaemon機能を活用

**利点**:
- agrrサービスは最小インスタンス数=1で常駐
- daemonの効果を最大化
- 責務の分離

## 結論と推奨事項

### ✅ **技術的実装は可能**（Litestreamパターン）

Litestreamと同様の方法で、コンテナ起動時にagrr daemonを自動起動できます。

**実装方法**: [AGRR_DAEMON_INTEGRATION.md](AGRR_DAEMON_INTEGRATION.md)を参照

ただし、以下の理由により**慎重な判断が必要**：

### ⚠️ daemon利用の判断基準

理由:
1. CloudRun/App Runnerのステートレス性と相性が悪い
2. コストとメモリ消費の増加（+$30-50/月、+200MB）
3. 効果が限定的（コンテナ再利用時のみ、初回は逆に遅くなる）
4. 運用複雑化（プロセス管理、デバッグ）

### ✅ 推奨アプローチ（優先度順）

1. **キャッシュ活用** - 即座に実装可能、コスト削減効果大
2. **非同期ジョブ** - UX向上、Railsの標準機能
3. **最小インスタンス数=1** - コールドスタート削減
4. **専用マイクロサービス化** - 大規模な場合のみ検討

### 🔄 daemon機能の有効な利用シーン

daemon機能は以下の環境で真価を発揮します：

- **オンプレミスサーバー** - 常時起動、長期稼働
- **EC2などのVM** - 永続的なプロセス管理が可能
- **開発環境** - ローカルでの高速な反復実行
- **バッチ処理サーバー** - 連続した大量実行

## 参考情報

- daemon起動時間: 2.4s → 0.5s (4.8倍高速化)
- メモリ使用量: 推定 +100-200MB
- UNIXソケット: `/tmp/agrr.sock`

## 関連ドキュメント

- [AGRR_DAEMON_INTEGRATION.md](AGRR_DAEMON_INTEGRATION.md) - 実装手順とトラブルシューティング

## 更新履歴

- 2025-10-19: 初版作成
- 2025-10-19: Litestreamパターンでの実装方法を追加

