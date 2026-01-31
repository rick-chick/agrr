# 契約: 管理者農場一覧表示修正

## 1. 機能名・スコープ
- **機能**: 管理者ユーザーで参照農場が表示されるように農場一覧 API を修正
- **スコープ**: Masters API の農場一覧（`/api/v1/masters/farms`）における管理者権限の扱いのみ

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadFarmListUseCase | 農場一覧画面初期表示、または農場一覧再取得 | LoadFarmListInputDto |

### 2.1 LoadFarmListUseCase 詳細
- **Input DTO**: `{ }`（空オブジェクト）
- **Output DTO**: `{ farms: Farm[] }`（Farm 配列）

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/farms | ユーザーがアクセス可能な農場一覧を取得 |

### 3.1 GET /api/v1/masters/farms
- **Request**:
  - Headers: `Authorization: Bearer {api_key}` または セッション Cookie
  - Params: なし
- **Response** (200):
  ```json
  [
    {
      "id": 1,
      "name": "string",
      "latitude": 35.6895,
      "longitude": 139.6917,
      "region": "jp",
      "is_reference": false,
      "user_id": 123,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  ]
  ```
- **Response** (200) - 管理者ユーザーの場合:
  ```json
  [
    {
      "id": 1,
      "name": "ユーザー農場1",
      "latitude": 35.6895,
      "longitude": 139.6917,
      "region": "jp",
      "is_reference": false,
      "user_id": 123,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    },
    {
      "id": 2,
      "name": "参照農場1",
      "latitude": 43.0642,
      "longitude": 141.3468,
      "region": "jp",
      "is_reference": true,
      "user_id": null,
      "created_at": "2024-01-01T00:00:00.000Z",
      "updated_at": "2024-01-01T00:00:00.000Z"
    }
  ]
  ```
- **Error** (401):
  ```json
  {
    "error": "Invalid API key"
  }
  ```
- **Error** (403):
  ```json
  {
    "error": "agricultural_tasks.flash.no_permission"
  }
  ```

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadFarmListUseCase | `GET /api/v1/masters/farms` |

## 5. 共有 DTO / 型定義

### TypeScript（フロント）
```typescript
// frontend/src/app/domain/farms/farm.ts
export interface Farm {
  id: number;
  name: string;
  latitude: number;
  longitude: number;
  region: string;
  description?: string | null;
  weather_data_status?: 'pending' | 'fetching' | 'completed' | 'failed';
  weather_data_progress?: number;
  weather_data_fetched_years?: number;
  weather_data_total_years?: number;
  is_reference?: boolean;
}

// frontend/src/app/usecase/farms/load-farm-list.dtos.ts
export interface FarmListDataDto {
  farms: Farm[];
}
```

### Ruby（サーバー）
```ruby
# lib/domain/farm/dtos/farm_list_input_dto.rb
module Domain
  module Farm
    module Dtos
      class FarmListInputDto
        attr_reader :is_admin

        def initialize(is_admin: false)
          @is_admin = is_admin
        end
      end
    end
  end
end
```

## 6. 実装チェックリスト

- [ ] サーバー: `Api::V1::Masters::FarmsController#index` で `current_user&.admin?` を判定し、`FarmListInputDto` に渡す
- [ ] サーバー: `FarmListInteractor` が管理者判定を受け取り、参照農場を含む農場一覧を返す
- [ ] フロント: 既存の `FarmListPresenter` と `FarmListView` が修正後のレスポンスを適切に処理
- [ ] テスト: 管理者ユーザーでの農場一覧取得テストを追加
- [ ] テスト: 一般ユーザーでは参照農場が含まれないことを確認
- [ ] **ナビリンク（本プロジェクト）**: 該当なし（既存機能修正）

## 7. 修正内容の詳細

### 現在の問題
`Api::V1::Masters::FarmsController#index` が `FarmListInteractor.call` を引数なしで呼び出しているため、`is_admin: false` のデフォルト値が使用され、管理者でも参照農場が取得されない。

### 修正方針
```ruby
# app/controllers/api/v1/masters/farms_controller.rb
def index
  input_valid?(:index) || return
  presenter = Presenters::Api::Farm::FarmListPresenter.new(view: self)
  interactor = Domain::Farm::Interactors::FarmListInteractor.new(
    output_port: presenter,
    gateway: farm_gateway,
    user_id: current_user.id
  )
  # 修正: is_admin を渡す
  input_dto = Domain::Farm::Dtos::FarmListInputDto.new(is_admin: current_user&.admin?)
  interactor.call(input_dto)
end
```

### 影響範囲
- Angular 農場一覧画面で、管理者ログイン時に参照農場も表示されるようになる
- HTML 版農場一覧（`farms_controller.rb`）は既に正しく動作しているため変更不要
- API レスポンスのスキーマは変更なし（既存の `Farm` モデルの JSON 表現）