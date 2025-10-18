# Region Data Documentation

AGRRの地域別（region）データに関するドキュメント集です。

---

## 📖 ドキュメント一覧

### 実装ガイド

- **[DATA_CREATION_GUIDE.md](./DATA_CREATION_GUIDE.md)** - 新しい地域データを作成するための完全ガイド
  - 他のLLMや開発者が再現できるステップバイステップの手順書
  - EU、中国、オーストラリアなど、新しい地域を追加する際に使用
  - 所要時間: 約3-4時間（地域により異なる）

- **[US_SUMMARY.md](./US_SUMMARY.md)** - US region実装の詳細サマリー
  - 実際の実施結果とデータ量
  - 遭遇した問題と解決策
  - パフォーマンス情報
  - 教訓と次のステップ

- **[BROWSER_LANGUAGE_DETECTION.md](./BROWSER_LANGUAGE_DETECTION.md)** - ブラウザ言語自動検出
  - Accept-Languageヘッダーの処理
  - 優先順位とマッピングルール
  - 動作確認結果

### 機能仕様

- **[feature.md](./feature.md)** - Region機能の仕様書
  - 機能概要と要件
  - データモデル
  - ユーザーインターフェース

- **[requirements.md](./requirements.md)** - Region機能の要件定義
  - ビジネス要件
  - 技術要件
  - 制約事項

- **[seed_data.md](./seed_data.md)** - シードデータの仕様
  - シードデータの構造
  - データ投入方法

---

## 🌍 対応地域

現在サポートされている地域：

| Region Code | 地域名 | 農場数 | 作物数 | 天気レコード数 | ステータス |
|------------|--------|-------|-------|--------------|---------|
| `jp` | Japan | 47 | 15 | 442,501 | ✅ 完了 |
| `us` | United States | 50 | 30 | 430,361 | ✅ 完了 |

**今後の追加予定:**
- `cn` - China
- `au` - Australia
- その他（要検討）

---

## 🚀 クイックスタート

### 新しい地域を追加したい場合

1. **[DATA_CREATION_GUIDE.md](./DATA_CREATION_GUIDE.md)** を開く
2. Phase 1から順番に実施
3. 各Phaseのチェックリストを確認
4. 問題が発生したら「トラブルシューティング」セクションを参照
5. **[US_SUMMARY.md](./US_SUMMARY.md)** で実際の例を確認

### LLMに依頼する場合

```markdown
以下のドキュメントに従って、<地域名> regionのデータを作成してください：
docs/region/DATA_CREATION_GUIDE.md

参考資料:
docs/region/US_SUMMARY.md
```

---

## 📊 データ構成

各regionには以下のデータが含まれます：

### 1. Reference Farms（参照農場）
- 主要農業地域30-50件
- 緯度・経度座標
- 天気データ（25年分程度）

### 2. Reference Crops（参照作物）
- 主要作物20-30件
- AI生成の栽培要件
- 成長ステージ情報（3-4ステージ/作物）

### 3. Interaction Rules（相互作用ルール）
- 連作障害ルール
- 科（family）ごとの影響度

---

## 🔧 関連スクリプト

各regionには以下のスクリプトが必要：

```
bin/
├── fetch_<region>_reference_weather_data  # 天気データ取得
├── fetch_<region>_crops_with_agrr         # 作物情報取得（AI）
├── translate_<region>_crop_stages         # 日本語→英語翻訳
└── export_<region>_crops_to_json          # JSON出力

db/
├── fixtures/
│   ├── <region>_reference_weather.json    # 天気データ
│   └── <region>_reference_crops.json      # 作物データ
└── seeds/
    └── <region>_seeds.rb                  # シードスクリプト
```

---

## ⚠️ 重要な注意事項

### agrrバイナリの日本語問題

agrrコマンドは内部で日本語プロンプトを使用しているため、**英語のクエリでもステージ名が日本語で返されます**。

**対応方法:**
1. 日本語のまま取得
2. 翻訳マッピングを作成
3. `translate_<region>_crop_stages`で一括翻訳

詳細は **[DATA_CREATION_GUIDE.md](./DATA_CREATION_GUIDE.md)** の「Phase 5: 日本語→英語翻訳」を参照。

### 天気データソースの選択

| データソース | 対象地域 | 特徴 | 注意点 |
|------------|---------|------|-------|
| `jma` | 日本のみ | 高品質 | 日本気象庁 |
| `noaa-ftp` | アメリカのみ | 無料、長期間 | precipitation等は含まれない |
| `openmeteo` | 全世界 | 簡単 | **無料枠に制限あり、大量データには不向き** |

**⚠️ openmeteoを使用する場合は、API制限を事前に確認してください。**

---

## 📚 参考資料

### 農業データ
- [FAO（国連食糧農業機関）](https://www.fao.org/)
- [World Bank Agriculture](https://data.worldbank.org/topic/agriculture-and-rural-development)

### 天気データ
- [Open-Meteo](https://open-meteo.com/)
- [NOAA](https://www.noaa.gov/)
- [気象庁](https://www.jma.go.jp/)

---

**最終更新:** 2025-10-18  
**管理者:** AGRR Development Team

