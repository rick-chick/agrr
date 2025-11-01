# CropFertilizeProfile モデル設計

## 概要

`agrr fertilize profile` コマンドの出力を `crop` に紐づける形で構造化したActiveRecordモデルの設計です。

既存の `Crop` ↔ `CropStage` パターンに従い、親子関係で構造化しています。

## モデル構造

### 1. CropFertilizeProfile（親モデル）

**役割**: 作物に対する肥料施用計画の全体情報を保持

**関連**:
- `belongs_to :crop` - 作物に紐づく
- `has_many :crop_fertilize_applications` - 施用計画の詳細を持つ

**主要な属性**:
- `crop_id` - 作物ID（必須）
- `total_n` - 総窒素量（g/m²、必須）
- `total_p` - 総リン量（g/m²、必須）
- `total_k` - 総カリ量（g/m²、必須）
- `sources` - 情報源（JSON配列、シリアライズ）
- `confidence` - 信頼度（0-1、デフォルト: 0.5）
- `notes` - 追加のガイダンス

### 2. CropFertilizeApplication（子モデル）

**役割**: 肥料施用計画の詳細（基肥/追肥ごと）を保持

**関連**:
- `belongs_to :crop_fertilize_profile` - プロファイルに紐づく

**主要な属性**:
- `crop_fertilize_profile_id` - プロファイルID（必須）
- `application_type` - 施用タイプ（"basal" または "topdress"、必須）
- `count` - 施用回数（必須、デフォルト: 1）
- `schedule_hint` - タイミングのガイダンス（例: "pre-plant", "fruiting"）
- `total_n`, `total_p`, `total_k` - このタイプの総量（g/m²、必須）
- `per_application_n`, `per_application_p`, `per_application_k` - 1回あたりの量（g/m²、追肥の場合のみ）

## データベース構造

```
crops
  └── crop_fertilize_profiles (1対多)
       └── crop_fertilize_applications (1対多)
```

## 使用方法

### agrr CLI の出力からモデルを作成

```ruby
# Step 1: agrr CLIで肥料プロファイルを取得
profile_json = `agrr fertilize profile --crop-file tomato_profile.json --json`
profile_data = JSON.parse(profile_json)

# Step 2: Cropを取得
crop = Crop.find_by(name: 'tomato')

# Step 3: モデルを作成
profile = CropFertilizeProfile.from_agrr_output(
  crop: crop,
  profile_data: profile_data
)
```

### agrr CLI の出力形式に変換

```ruby
# モデルから agrr CLI の期待する形式に変換
profile = CropFertilizeProfile.includes(:crop_fertilize_applications).find(1)
agrr_output = profile.to_agrr_output
```

## agrr CLI の出力形式との対応

### 入力形式（agrr fertilize profile のJSON出力）

```json
{
  "crop": {"crop_id": "1", "name": "tomato"},
  "totals": {"N": 18.0, "P": 5.0, "K": 12.0},
  "applications": [
    {
      "type": "basal",
      "count": 1,
      "schedule_hint": "pre-plant",
      "nutrients": {"N": 6.0, "P": 2.0, "K": 3.0},
      "per_application": null
    },
    {
      "type": "topdress",
      "count": 2,
      "schedule_hint": "fruiting",
      "nutrients": {"N": 12.0, "P": 3.0, "K": 9.0},
      "per_application": {"N": 6.0, "P": 1.5, "K": 4.5}
    }
  ],
  "sources": ["inmemory"],
  "confidence": 0.5,
  "notes": "..."
}
```

### データベース構造へのマッピング

- `crop` → `CropFertilizeProfile.crop_id` で `Crop` に紐づけ
- `totals` → `CropFertilizeProfile.total_n`, `total_p`, `total_k`
- `applications[]` → `CropFertilizeApplication` レコード（複数）
  - `type` → `application_type` ("basal" or "topdress")
  - `count` → `count`
  - `schedule_hint` → `schedule_hint`
  - `nutrients` → `total_n`, `total_p`, `total_k`
  - `per_application` → `per_application_n`, `per_application_p`, `per_application_k` (nullable)
- `sources` → `sources` (JSON配列としてシリアライズ)
- `confidence` → `confidence`
- `notes` → `notes`

## 既存パターンとの対応

この設計は既存の `Crop` ↔ `CropStage` パターンに従っています：

| 既存パターン | 新規パターン |
|------------|------------|
| `Crop` | `Crop` |
| `CropStage` | `CropFertilizeProfile` |
| `TemperatureRequirement` | `CropFertilizeApplication` |
| `belongs_to :crop` | `belongs_to :crop` |
| `has_many :crop_stages` | `has_many :crop_fertilize_profiles` |

## バリデーション

### CropFertilizeProfile
- `crop_id`: 必須
- `total_n`, `total_p`, `total_k`: 必須、0以上
- `confidence`: 必須、0-1の範囲

### CropFertilizeApplication
- `crop_fertilize_profile_id`: 必須
- `application_type`: 必須、"basal" または "topdress"
- `count`: 必須、1以上の整数
- `total_n`, `total_p`, `total_k`: 必須、0以上
- 追肥で複数回の場合、`per_application_*` の設定を推奨（警告のみ）

## マイグレーション

```bash
# マイグレーション実行
rails db:migrate
```

作成されるテーブル:
- `crop_fertilize_profiles`
- `crop_fertilize_applications`

## 今後の拡張

1. **バージョン管理**: 1つのcropに複数のprofileを持たせる（履歴管理）
2. **カスタマイズ**: ユーザーが推奨値を編集できる機能
3. **計算機能**: 実際の栽培面積から必要な肥料量を計算するメソッド

