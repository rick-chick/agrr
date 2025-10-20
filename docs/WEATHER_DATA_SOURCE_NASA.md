# NASA POWER 天気データソースへの移行

## 概要

天気データソースを**NASA POWER API**に変更しました。これにより、インドを含む全世界の天気データを取得できるようになりました。

## 変更内容

### 1. データソースの変更

- **旧**: JMA (日本気象庁) - 日本のみ対応
- **新**: NASA POWER - 全世界対応（1984年〜現在）

### 2. NASA POWER の特徴

#### メリット
- ✅ **グローバルカバレッジ**: 世界中のどの地域でもデータ取得可能
- ✅ **長期データ**: 1984年から現在までの40年以上のデータ
- ✅ **無料**: APIキー不要、レート制限あり（1秒に1リクエスト）
- ✅ **信頼性**: NASA提供のグリッドベースデータ（衛星+地上観測の融合）
- ✅ **農業向け**: 農業に必要なパラメータを提供

#### データ項目
- 最高気温・最低気温・平均気温
- 降水量
- 風速
- 日射量（日照時間に変換）

#### データ解像度
- 空間解像度: 0.5° × 0.625° グリッド（約50km）
- 時間解像度: 日次データ

### 3. 設定方法

#### 環境変数

```bash
# .env または docker-compose.yml に設定
WEATHER_DATA_SOURCE=nasa-power
```

**利用可能なオプション**:
- `nasa-power` (デフォルト) - グローバル対応、インドに最適
- `openmeteo` - グローバル対応、より詳細なデータ
- `jma` - 日本のみ
- `noaa-ftp` - 米国の長期データ

#### Docker Compose

`docker-compose.yml`の`environment`セクションに追加済み：

```yaml
environment:
  - WEATHER_DATA_SOURCE=nasa-power  # NASA POWER: Global coverage (1984-present), ideal for India
```

### 4. 使用方法

#### Railsジョブ（自動）

Farmを作成すると、自動的にNASA POWERから天気データを取得します：

```ruby
# app/jobs/fetch_weather_data_job.rb
# 自動的に WEATHER_DATA_SOURCE 環境変数を参照
FetchWeatherDataJob.perform_now(
  latitude: 28.6139,   # デリー
  longitude: 77.2090,
  start_date: Date.new(2024, 1, 1),
  end_date: Date.new(2024, 12, 31)
)
```

#### CLIから直接実行

```bash
# インド・デリーの2024年データを取得
docker compose exec web lib/core/agrr weather \
  --location 28.6139,77.2090 \
  --start-date 2024-01-01 \
  --end-date 2024-12-31 \
  --data-source nasa-power \
  --json
```

### 5. 動作確認済み地域

#### インド
```bash
# デリー
docker compose exec web lib/core/agrr weather \
  --location 28.6139,77.2090 \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --data-source nasa-power
```

結果例：
```
2024-01-01: 5.86°C - 21.11°C, 0.0mm
2024-01-02: 5.08°C - 20.87°C, 0.0mm
2024-01-03: 6.85°C - 21.48°C, 0.0mm
```

#### 日本
```bash
# 東京
docker compose exec web lib/core/agrr weather \
  --location 35.6762,139.6503 \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --data-source nasa-power
```

### 6. トラブルシューティング

#### データが取得できない場合

1. **環境変数を確認**:
   ```bash
   docker compose exec web rails runner 'puts ENV["WEATHER_DATA_SOURCE"]'
   # => nasa-power
   ```

2. **コンテナを再起動**:
   ```bash
   docker compose restart web
   ```

3. **直接CLIでテスト**:
   ```bash
   docker compose exec web lib/core/agrr weather \
     --location YOUR_LAT,YOUR_LON \
     --start-date 2024-01-01 \
     --end-date 2024-01-07 \
     --data-source nasa-power \
     --json
   ```

#### レート制限エラー

NASA POWERは1秒に1リクエストの制限があります。大量のデータを取得する場合は、ジョブが自動的に待機します。

### 7. パフォーマンス

- **単一リクエスト**: 7日分 → 約3-5秒
- **長期データ**: 1年分 → 約10-15秒
- **レート制限**: 1秒に1リクエスト（自動待機）

### 8. バグ修正

#### 修正したバグ

**Bug**: `fetch_weather_data_job.rb`の135行目で配列インデックスエラー

```ruby
# ❌ Before
if index == 0 || index == weather_data['data']['data'].length - 1

# ✅ After
if index == 0 || index == weather_data['data'].length - 1
```

**原因**: JSONレスポンスの構造を誤解していた
- 正しい構造: `weather_data['data']` は配列
- 間違った構造: `weather_data['data']['data']` は存在しない

### 9. 今後の改善

- [ ] OpenMeteoとの比較テスト
- [ ] データ品質の検証（実測値との比較）
- [ ] キャッシュ機能の追加（重複リクエスト防止）
- [ ] 予測データの統合

## 参考資料

- [NASA POWER Documentation](https://power.larc.nasa.gov/docs/)
- [NASA POWER API](https://power.larc.nasa.gov/api/temporal/daily/point)
- [Data Parameters](https://power.larc.nasa.gov/docs/services/api/temporal/daily/)

## 関連ファイル

- `app/jobs/fetch_weather_data_job.rb` - Railsバックグラウンドジョブ
- `lib/core/_internal/agrr_core/adapter/gateways/weather_nasa_power_gateway.py` - NASA POWERゲートウェイ実装
- `lib/core/_internal/agrr_core/framework/agrr_core_container.py` - DIコンテナ（データソース切り替え）
- `docker-compose.yml` - 環境変数設定
- `env.example` - 環境変数のテンプレート

## まとめ

NASA POWERへの移行により、AGRRプラットフォームは**真のグローバル対応**となりました。インドを含む世界中のどの地域でも、1984年以降の天気データを取得できます。

