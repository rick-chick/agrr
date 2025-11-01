# AGRR CLI構造とActiveRecordモデル設計の整合性比較

## 📊 比較対象

- **AGRR CLI出力**: `agrr fertilize profile` の実際のJSON出力
- **ActiveRecordモデル**: `CropFertilizeProfile` と `CropFertilizeApplication`

## 🔍 項目ごとの整合性チェック

### 1. crop情報の扱い

#### AGRR CLI構造
```json
{
  "crop": {
    "crop_id": "tomato",
    "name": "tomato"
  }
}
```

#### ActiveRecord設計
- `CropFertilizeProfile.belongs_to :crop`
- `crop_id` で `Crop` モデルに紐づけ
- `to_agrr_output` で `crop.id.to_s` と `crop.name` を返す

#### ✅ 整合性: **良好**

**理由**:
- AGRR CLIの `crop_id` は文字列だが、モデルでは `crop.id.to_s` で文字列化しているため問題なし
- AGRR CLIは `crop_id` と `name` を返すが、モデル側は `Crop` モデルを参照できるため、`name` は常に取得可能
- `from_agrr_output` では `Crop` モデルを直接渡すため、`crop_id` の文字列変換は不要

**注意点**:
- AGRR CLIの `crop_id` は作物名（"tomato"）の場合があるが、モデルでは数値IDを想定
- `from_agrr_output` メソッドは `Crop` オブジェクトを直接受け取るため、この問題は発生しない

---

### 2. totals（総肥料量）の扱い

#### AGRR CLI構造
```json
{
  "totals": {
    "N": 18.0,
    "P": 5.0,
    "K": 12.0
  }
}
```

#### ActiveRecord設計
- `CropFertilizeProfile.total_n` (float, NOT NULL)
- `CropFertilizeProfile.total_p` (float, NOT NULL)
- `CropFertilizeProfile.total_k` (float, NOT NULL)

#### ✅ 整合性: **良好**

**理由**:
- フィールド名: `N` → `total_n`, `P` → `total_p`, `K` → `total_k` で一貫
- データ型: floatで整合
- 必須項目: NOT NULL制約で整合
- 単位: 両方とも g/m² で整合

**マッピング**:
- `from_agrr_output`: `profile_data['totals']['N']` → `total_n` ✅
- `to_agrr_output`: `total_n` → `'N' => total_n` ✅

---

### 3. applications（施用計画）の扱い

#### AGRR CLI構造
```json
{
  "applications": [
    {
      "type": "basal",
      "count": 1,
      "schedule_hint": "pre-plant",
      "nutrients": {
        "N": 6.0,
        "P": 2.0,
        "K": 3.0
      },
      "per_application": null
    },
    {
      "type": "topdress",
      "count": 2,
      "schedule_hint": "fruiting",
      "nutrients": {
        "N": 12.0,
        "P": 3.0,
        "K": 9.0
      },
      "per_application": {
        "N": 6.0,
        "P": 1.5,
        "K": 4.5
      }
    }
  ]
}
```

#### ActiveRecord設計
- `CropFertilizeApplication` モデル（複数レコード）
- `application_type` (string, "basal" or "topdress")
- `count` (integer, NOT NULL)
- `schedule_hint` (string, nullable)
- `total_n`, `total_p`, `total_k` (float, NOT NULL) - nutrientsから
- `per_application_n`, `per_application_p`, `per_application_k` (float, nullable)

#### ✅ 整合性: **良好**

**理由**:
- 構造: 配列 → `has_many` 関連で整合
- `type` → `application_type`: ✅
- `count`: ✅
- `schedule_hint`: ✅
- `nutrients` → `total_n/p/k`: ✅
- `per_application`: nullableで整合（基肥はnull、追肥は値あり）

**マッピング**:
```ruby
# from_agrr_output
app_data['type'] → application_type ✅
app_data['count'] → count ✅
app_data['schedule_hint'] → schedule_hint ✅
app_data['nutrients']['N'] → total_n ✅
app_data['per_application']&.dig('N') → per_application_n ✅ (nullable)

# to_agrr_output
application_type → 'type' ✅
count → 'count' ✅
schedule_hint → 'schedule_hint' ✅
total_n → 'nutrients'['N'] ✅
per_application_n → 'per_application'['N'] ✅ (条件付き)
```

**バリデーション**:
- `application_type`: "basal" or "topdress" のみ許可 ✅
- `count`: 1以上の整数 ✅
- 追肥で複数回の場合、`per_application_*` の設定を推奨（警告のみ） ✅

---

### 4. sources（情報源）の扱い

#### AGRR CLI構造
```json
{
  "sources": ["inmemory"]
}
```

#### ActiveRecord設計
- `CropFertilizeProfile.sources` (text)
- `serialize :sources, coder: JSON`
- 配列として扱う

#### ✅ 整合性: **良好**

**理由**:
- データ型: JSON配列 → serializeでJSON配列として保存 ✅
- `after_initialize` で文字列と配列の両方に対応 ✅
- `from_agrr_output`: `profile_data['sources'] || []` ✅
- `to_agrr_output`: `sources || []` ✅

**実装の確認**:
```ruby
# from_agrr_output
sources: profile_data['sources'] || []  # 配列をそのまま保存 ✅

# to_agrr_output
'sources' => sources || []  # 配列をそのまま返す ✅
```

---

### 5. confidence（信頼度）の扱い

#### AGRR CLI構造
```json
{
  "confidence": 0.5
}
```

#### ActiveRecord設計
- `CropFertilizeProfile.confidence` (float, NOT NULL, default: 0.5)
- バリデーション: 0-1の範囲

#### ✅ 整合性: **良好**

**理由**:
- データ型: floatで整合 ✅
- デフォルト値: 0.5で整合 ✅
- バリデーション: 0-1の範囲で整合 ✅
- `from_agrr_output`: `profile_data['confidence'] || 0.5` ✅
- `to_agrr_output`: `confidence` ✅

---

### 6. notes（メモ）の扱い

#### AGRR CLI構造
```json
{
  "notes": "In-memory gateway placeholder"
}
```

#### ActiveRecord設計
- `CropFertilizeProfile.notes` (text, nullable)

#### ✅ 整合性: **良好**

**理由**:
- データ型: textで整合 ✅
- nullable: ✅
- `from_agrr_output`: `profile_data['notes']` ✅
- `to_agrr_output`: `notes` ✅

---

### 7. データ型とnull許容性

| 項目 | AGRR CLI | ActiveRecord | 整合性 |
|------|----------|--------------|--------|
| `crop.crop_id` | string | `crop_id` (integer, FK) | ✅ モデル側で文字列化 |
| `crop.name` | string | `Crop.name` (string) | ✅ |
| `totals.N` | float | `total_n` (float, NOT NULL) | ✅ |
| `totals.P` | float | `total_p` (float, NOT NULL) | ✅ |
| `totals.K` | float | `total_k` (float, NOT NULL) | ✅ |
| `applications[].type` | string | `application_type` (string, NOT NULL) | ✅ |
| `applications[].count` | integer | `count` (integer, NOT NULL) | ✅ |
| `applications[].schedule_hint` | string/null | `schedule_hint` (string, nullable) | ✅ |
| `applications[].nutrients.N` | float | `total_n` (float, NOT NULL) | ✅ |
| `applications[].per_application.N` | float/null | `per_application_n` (float, nullable) | ✅ |
| `sources` | array | `sources` (text, JSON serialized) | ✅ |
| `confidence` | float | `confidence` (float, NOT NULL) | ✅ |
| `notes` | string/null | `notes` (text, nullable) | ✅ |

#### ✅ 整合性: **良好**

すべての項目で型とnull許容性が整合している。

---

### 8. 変換ロジック（from_agrr_output）

```ruby
def self.from_agrr_output(crop:, profile_data:)
  profile = create!(
    crop: crop,
    total_n: profile_data['totals']['N'],      # ✅
    total_p: profile_data['totals']['P'],      # ✅
    total_k: profile_data['totals']['K'],      # ✅
    sources: profile_data['sources'] || [],   # ✅
    confidence: profile_data['confidence'] || 0.5,  # ✅
    notes: profile_data['notes']              # ✅
  )

  profile_data['applications'].each do |app_data|
    profile.crop_fertilize_applications.create!(
      application_type: app_data['type'],                    # ✅
      count: app_data['count'],                              # ✅
      schedule_hint: app_data['schedule_hint'],             # ✅
      total_n: app_data['nutrients']['N'],                   # ✅
      total_p: app_data['nutrients']['P'],                  # ✅
      total_k: app_data['nutrients']['K'],                  # ✅
      per_application_n: app_data['per_application']&.dig('N'),  # ✅ nullable対応
      per_application_p: app_data['per_application']&.dig('P'),  # ✅ nullable対応
      per_application_k: app_data['per_application']&.dig('K')   # ✅ nullable対応
    )
  end
end
```

#### ✅ 整合性: **良好**

- すべてのフィールドが正しくマッピングされている
- `per_application` がnullの場合も安全に処理（`&.dig` を使用）
- デフォルト値の設定も適切

---

### 9. 変換ロジック（to_agrr_output）

```ruby
def to_agrr_output
  {
    'crop' => {
      'crop_id' => crop.id.to_s,      # ✅ 数値IDを文字列化
      'name' => crop.name              # ✅
    },
    'totals' => {
      'N' => total_n,                  # ✅
      'P' => total_p,                  # ✅
      'K' => total_k                   # ✅
    },
    'applications' => crop_fertilize_applications.order(:application_type, :id).map do |app|
      app_hash = {
        'type' => app.application_type,           # ✅
        'count' => app.count,                      # ✅
        'schedule_hint' => app.schedule_hint,      # ✅
        'nutrients' => {
          'N' => app.total_n,                      # ✅
          'P' => app.total_p,                      # ✅
          'K' => app.total_k                       # ✅
        }
      }

      # per_applicationがある場合のみ追加
      if app.per_application_n.present? || ...
        app_hash['per_application'] = {
          'N' => app.per_application_n,            # ✅
          'P' => app.per_application_p,            # ✅
          'K' => app.per_application_k             # ✅
        }
      else
        app_hash['per_application'] = nil         # ✅
      end
    end,
    'sources' => sources || [],                    # ✅
    'confidence' => confidence,                    # ✅
    'notes' => notes                               # ✅
  }
end
```

#### ✅ 整合性: **良好**

- すべてのフィールドが正しくマッピングされている
- `per_application` の条件付き出力も適切
- AGRR CLIの期待する形式と完全に一致

---

### 10. バリデーション

#### AGRR CLIの期待値
- `totals.N/P/K`: 必須、0以上
- `applications[].type`: "basal" or "topdress"
- `applications[].count`: 1以上
- `applications[].nutrients.N/P/K`: 0以上
- `confidence`: 0-1の範囲

#### ActiveRecordバリデーション
```ruby
# CropFertilizeProfile
validates :total_n, presence: true, numericality: { greater_than_or_equal_to: 0 }  # ✅
validates :total_p, presence: true, numericality: { greater_than_or_equal_to: 0 }  # ✅
validates :total_k, presence: true, numericality: { greater_than_or_equal_to: 0 }  # ✅
validates :confidence, presence: true, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 1 }  # ✅

# CropFertilizeApplication
validates :application_type, inclusion: { in: %w[basal topdress] }  # ✅
validates :count, numericality: { only_integer: true, greater_than: 0 }  # ✅
validates :total_n, numericality: { greater_than_or_equal_to: 0 }  # ✅
validates :total_p, numericality: { greater_than_or_equal_to: 0 }  # ✅
validates :total_k, numericality: { greater_than_or_equal_to: 0 }  # ✅
```

#### ✅ 整合性: **良好**

すべてのバリデーションがAGRR CLIの期待値と一致している。

---

### 11. データベース制約

#### マイグレーション設計
```ruby
# crop_fertilize_profiles
t.references :crop, null: false, foreign_key: true        # ✅
t.float :total_n, null: false                              # ✅
t.float :total_p, null: false                              # ✅
t.float :total_k, null: false                              # ✅
t.float :confidence, null: false, default: 0.5            # ✅

# crop_fertilize_applications
t.references :crop_fertilize_profile, null: false, foreign_key: true  # ✅
t.string :application_type, null: false                     # ✅
t.integer :count, null: false, default: 1                   # ✅
t.float :total_n, null: false                              # ✅
t.float :per_application_n                                 # ✅ nullable（適切）
```

#### ✅ 整合性: **良好**

データベース制約がモデルのバリデーションと一致している。

---

## 📋 整合性サマリー

| 項目 | 整合性 | 備考 |
|------|--------|------|
| 1. crop情報 | ✅ 良好 | モデル側で文字列化対応 |
| 2. totals | ✅ 良好 | 完全一致 |
| 3. applications | ✅ 良好 | 完全一致 |
| 4. sources | ✅ 良好 | JSON配列として適切にシリアライズ |
| 5. confidence | ✅ 良好 | 完全一致 |
| 6. notes | ✅ 良好 | 完全一致 |
| 7. データ型 | ✅ 良好 | すべて整合 |
| 8. from_agrr_output | ✅ 良好 | 完全対応 |
| 9. to_agrr_output | ✅ 良好 | 完全対応 |
| 10. バリデーション | ✅ 良好 | AGRR CLIの期待値と一致 |
| 11. DB制約 | ✅ 良好 | 適切 |

## ✅ 結論

**すべての項目で整合性が取れています。**

設計は以下の点で優れています：
1. AGRR CLIの構造を完全に反映
2. データ型とnull許容性が適切
3. 双方向の変換（from/to）が実装済み
4. バリデーションとDB制約が一致
5. 既存の `Crop` ↔ `CropStage` パターンに準拠

## 🔍 潜在的な注意点

1. **crop_idの扱い**: 
   - AGRR CLIの出力では `crop_id` が文字列（"tomato"）の場合があるが、モデルでは数値IDを想定
   - `from_agrr_output` では `Crop` オブジェクトを直接受け取るため問題なし

2. **複数プロファイル**:
   - 現在は1つのcropに1つのprofileを想定
   - 将来、履歴管理のために複数バージョンを持つ可能性あり（インデックスは対応済み）

3. **sourcesの形式**:
   - 現在は文字列配列だが、将来的にオブジェクト配列になる可能性（現在の実装で対応可能）

