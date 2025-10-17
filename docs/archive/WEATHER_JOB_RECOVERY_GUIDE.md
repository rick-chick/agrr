# 参照農場天気データ更新ジョブ - リカバリーガイド

## 概要

本ドキュメントは、`UpdateReferenceWeatherDataJob`が失敗した場合の診断と復旧手順を記載しています。

## 前提条件

- Dockerコンテナが起動していること
- データベースにアクセスできること
- 管理者権限があること

---

## 1. 障害の検知

### 1.1 ログの確認

```bash
# 開発環境
docker compose logs web | grep -A 10 "UpdateReferenceWeatherDataJob"

# 本番環境（AWS App Runner）
# ログストリームを確認
```

### 1.2 期待されるログ

#### 正常時
```
🌤️  参照農場の天気データ更新を開始
📋 参照農場47件を発見
📅 取得期間: 2025-10-06 〜 2025-10-13
✅ [Farm#24] '三重' の天気データ更新ジョブをエンキュー
...
🎉 参照農場47件の天気データ更新ジョブをエンキュー完了（実行時間: 0.32秒）
```

#### 異常時
```
❌ [UpdateReferenceWeatherDataJob] 予期しないエラーが発生しました
   エラー: StandardError - Connection timeout
   Backtrace: ...
```

---

## 2. 診断手順

### 2.1 最終実行日時の確認

```ruby
# Railsコンソール
docker compose exec web rails console

# 最新のジョブ実行を確認
SolidQueue::Job.where(class_name: 'UpdateReferenceWeatherDataJob')
  .order(created_at: :desc)
  .limit(5)
  .each { |j| puts "#{j.created_at}: #{j.finished_at.present? ? '完了' : '実行中/失敗'}" }
```

### 2.2 参照農場の天気データ鮮度確認

```ruby
# 各参照農場の最新データを確認
Farm.reference.includes(:weather_location).each do |farm|
  if farm.weather_location
    latest_date = farm.weather_location.weather_data.maximum(:date)
    days_old = Date.today - latest_date if latest_date
    puts "#{farm.name}: #{latest_date || '未取得'} (#{days_old}日前)" if days_old && days_old > 2
  else
    puts "#{farm.name}: 天気データなし"
  end
end
```

### 2.3 失敗したジョブの確認

```ruby
# 失敗したジョブを確認
failed_jobs = SolidQueue::Job.where(
  class_name: 'UpdateReferenceWeatherDataJob',
  finished_at: nil
).where('created_at < ?', 1.hour.ago)

failed_jobs.each do |job|
  puts "Job ID: #{job.id}, Created: #{job.created_at}"
  puts "Arguments: #{job.arguments}"
end
```

---

## 3. リカバリー手順

### 3.1 即座の再実行（最優先）

```bash
# 開発環境
docker compose exec web rails runner "UpdateReferenceWeatherDataJob.perform_now"

# 本番環境
# AWS App Runner コンソールからタスク実行
# または
rails runner "UpdateReferenceWeatherDataJob.perform_now"
```

### 3.2 特定の農場のみ再実行

```bash
# 北海道の天気データのみ更新
docker compose exec web rails runner "
  farm = Farm.find_by(name: '北海道', is_reference: true)
  if farm
    FetchWeatherDataJob.perform_later(
      farm_id: farm.id,
      latitude: farm.latitude,
      longitude: farm.longitude,
      start_date: Date.today - 7.days,
      end_date: Date.today
    )
    puts '✅ 北海道の天気データ更新ジョブをエンキュー'
  else
    puts '❌ 農場が見つかりません'
  end
"
```

### 3.3 複数の農場を再実行

```bash
# 特定の農場リストのみ更新
docker compose exec web rails runner "
  farm_names = ['北海道', '東京', '大阪']
  farm_names.each do |name|
    farm = Farm.find_by(name: name, is_reference: true)
    next unless farm
    
    FetchWeatherDataJob.perform_later(
      farm_id: farm.id,
      latitude: farm.latitude,
      longitude: farm.longitude,
      start_date: Date.today - 7.days,
      end_date: Date.today
    )
    puts \"✅ #{name}の天気データ更新ジョブをエンキュー\"
  end
"
```

### 3.4 古いデータの一括更新

```bash
# 3日以上古いデータを持つ農場を更新
docker compose exec web rails runner "
  Farm.reference.includes(:weather_location).each do |farm|
    next unless farm.weather_location
    
    latest_date = farm.weather_location.weather_data.maximum(:date)
    next unless latest_date
    next if Date.today - latest_date <= 2  # 2日以内は更新不要
    
    FetchWeatherDataJob.perform_later(
      farm_id: farm.id,
      latitude: farm.latitude,
      longitude: farm.longitude,
      start_date: Date.today - 7.days,
      end_date: Date.today
    )
    puts \"✅ #{farm.name}の天気データ更新ジョブをエンキュー（最終更新: #{latest_date}）\"
  end
"
```

---

## 4. よくあるエラーと対処法

### 4.1 データベース接続エラー

**症状:**
```
ActiveRecord::ConnectionNotEstablished: Connection lost
```

**対処法:**
1. データベースの稼働状況を確認
2. 接続設定を確認 (`config/database.yml`)
3. 自動リトライ（10秒間隔、5回まで）で回復しない場合は手動再実行

### 4.2 API タイムアウト

**症状:**
```
Timeout::Error: execution expired
```

**対処法:**
1. agrrコマンドが正常に動作するか確認
2. ネットワーク接続を確認
3. 特定の農場で繰り返し失敗する場合は個別に調査

```bash
# agrrコマンドの直接実行テスト
docker compose exec web ./lib/core/agrr weather \
  --location "35.6895,139.6917" \
  --start-date "2025-10-06" \
  --end-date "2025-10-13" \
  --data-source jma \
  --json
```

### 4.3 座標データ不正

**症状:**
```
ArgumentError: Invalid latitude or longitude
```

**対処法:**
1. 参照農場の座標を確認
```ruby
Farm.reference.where("latitude IS NULL OR longitude IS NULL").each do |farm|
  puts "#{farm.name}: latitude=#{farm.latitude}, longitude=#{farm.longitude}"
end
```

2. 座標を修正
```ruby
farm = Farm.find_by(name: "北海道", is_reference: true)
farm.update!(latitude: 43.0642, longitude: 141.3469)
```

### 4.4 ディスク容量不足

**症状:**
```
Errno::ENOSPC: No space left on device
```

**対処法:**
1. ディスク使用量を確認
```bash
df -h
```

2. 不要なログやジョブ履歴を削除
```ruby
# 完了したジョブを削除（30日以上前）
SolidQueue::Job.where("finished_at < ?", 30.days.ago).delete_all
```

---

## 5. 予防策

### 5.1 定期監視の設定

```bash
# Cronで毎日チェック（将来実装）
# 0 6 * * * /path/to/check_weather_data_freshness.sh
```

### 5.2 アラートの設定（将来実装）

- Slack通知
- メール通知
- ダッシュボード表示

### 5.3 健全性チェックスクリプト

```ruby
# script/check_weather_freshness.rb
reference_farms = Farm.reference.includes(:weather_location)
stale_farms = []

reference_farms.each do |farm|
  next unless farm.weather_location
  
  latest_date = farm.weather_location.weather_data.maximum(:date)
  if latest_date.nil? || Date.today - latest_date > 2
    stale_farms << farm
  end
end

if stale_farms.any?
  puts "⚠️  古いデータの農場: #{stale_farms.map(&:name).join(', ')}"
  exit 1
else
  puts "✅ すべての参照農場のデータは最新です"
  exit 0
end
```

---

## 6. エスカレーション

### 6.1 いつエスカレーションすべきか

- 3回以上手動再実行しても失敗する
- すべての参照農場で失敗する
- データベースに接続できない
- agrrコマンドが動作しない

### 6.2 エスカレーション時の情報

以下の情報を収集してエスカレーション：

1. エラーメッセージとスタックトレース
2. 最終成功日時
3. 失敗した農場のリスト
4. ログファイル（直近1時間分）
5. データベース接続状況
6. ディスク使用量

```bash
# 情報収集スクリプト
echo "=== エラーログ ===" > /tmp/weather_job_debug.txt
docker compose logs web --tail 100 | grep -A 10 UpdateReferenceWeatherDataJob >> /tmp/weather_job_debug.txt

echo "\n=== ディスク使用量 ===" >> /tmp/weather_job_debug.txt
df -h >> /tmp/weather_job_debug.txt

echo "\n=== データベース状態 ===" >> /tmp/weather_job_debug.txt
docker compose exec web rails runner "
  puts 'Farms: ' + Farm.reference.count.to_s
  puts 'Weather locations: ' + WeatherLocation.count.to_s
  puts 'Weather data: ' + WeatherDatum.count.to_s
" >> /tmp/weather_job_debug.txt

cat /tmp/weather_job_debug.txt
```

---

## 7. テスト実行

### 7.1 単体テスト

```bash
docker compose run --rm test bundle exec rails test test/jobs/update_reference_weather_data_job_test.rb
```

### 7.2 手動統合テスト

```bash
# 1. ジョブを実行
docker compose exec web rails runner "UpdateReferenceWeatherDataJob.perform_now"

# 2. ログを確認
docker compose logs web --tail 100 | grep UpdateReferenceWeatherDataJob

# 3. ジョブキューを確認
docker compose exec web rails runner "
  puts 'Enqueued: ' + SolidQueue::Job.where(finished_at: nil, class_name: 'FetchWeatherDataJob').count.to_s
  puts 'Completed: ' + SolidQueue::Job.where.not(finished_at: nil).where(class_name: 'FetchWeatherDataJob').where('created_at > ?', 1.hour.ago).count.to_s
"

# 4. データの鮮度を確認
docker compose exec web rails runner "
  Farm.reference.includes(:weather_location).limit(5).each do |farm|
    latest = farm.weather_location&.weather_data&.maximum(:date)
    puts \"#{farm.name}: #{latest || '未取得'}\"
  end
"
```

---

## 8. 参考資料

- [テスト計画書](./TEST_PLAN_UPDATE_REFERENCE_WEATHER_JOB.md)
- [天気データフロー](./WEATHER_DATA_FLOW.md)
- [Solid Queue Documentation](https://github.com/rails/solid_queue)
- [ActiveJob Guide](https://guides.rubyonrails.org/active_job_basics.html)

---

**最終更新**: 2025-10-13  
**作成者**: AI Test Design Specialist  
**バージョン**: 1.0  
**レビュー担当**: 開発チーム

