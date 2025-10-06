# Clean Architecture 設計書

## 概要

このプロジェクトはClean Architectureに基づいて設計されています。層の依存関係を明確にし、テスタビリティと保守性を向上させています。

## 層構造

```
lib/
├── domain/                    # ドメイン層（最内層）
│   ├── farm/                  # 農場ドメイン
│   │   ├── entities/          # エンティティ
│   │   ├── interactors/       # ユースケース（インタラクター）
│   │   └── gateways/          # インターフェース
│   └── field/                 # 圃場ドメイン
│       ├── entities/          # エンティティ
│       ├── interactors/       # ユースケース（インタラクター）
│       └── gateways/          # インターフェース
└── adapters/                  # アダプター層（最外層）
    ├── farm/                  # 農場アダプター
    │   ├── controllers/       # REST API コントローラー
    │   └── gateways/          # データアクセス実装
    └── field/                 # 圃場アダプター
        ├── controllers/       # REST API コントローラー
        └── gateways/          # データアクセス実装
```

## 依存関係ルール

1. **ドメイン層**: 外部に依存しない（純粋なビジネスロジック）
2. **アダプター層**: ドメイン層のインターフェースを実装
3. **依存性逆転**: ドメイン層がアダプター層のインターフェースを定義

## 命名規則

### ファイル名
- `<model>_<device>_<action>_<component>.rb`
- 例: `farm_memory_create_interactor.rb`, `field_api_update_gateway.rb`

### コンポーネント
- **Interactor**: モデルアクションごと（FarmCreateInteractor, FieldUpdateInteractor）
- **Gateway**: モデルごと（FarmGateway, FieldGateway）
- **Controller**: REST API エンドポイント

## 実装方針

### テストファースト
1. テストを先に書く
2. 最小限の実装でテストを通す
3. リファクタリング

### 依存性注入
- パッチは使用しない
- コンストラクタインジェクションを使用
- テストではモックをconftestに定義

### 1クラス1ユースケース
- 各インタラクターは単一の責任を持つ
- 複雑な処理は複数のインタラクターに分割

## ドメインモデル

### 農場 (Farm)
- 複数の圃場を持つ
- ユーザーに属する
- 名前を持つ

### 圃場 (Field)
- 農場に属する
- ユーザーに属する
- 名前を持つ
- 位置情報を持つ（オプション）

## API エンドポイント

### 農場
- `GET /api/v1/farms` - 農場一覧
- `POST /api/v1/farms` - 農場作成
- `GET /api/v1/farms/:id` - 農場詳細
- `PUT /api/v1/farms/:id` - 農場更新
- `DELETE /api/v1/farms/:id` - 農場削除

### 圃場
- `GET /api/v1/farms/:farm_id/fields` - 圃場一覧
- `POST /api/v1/farms/:farm_id/fields` - 圃場作成
- `GET /api/v1/farms/:farm_id/fields/:id` - 圃場詳細
- `PUT /api/v1/farms/:farm_id/fields/:id` - 圃場更新
- `DELETE /api/v1/farms/:farm_id/fields/:id` - 圃場削除
