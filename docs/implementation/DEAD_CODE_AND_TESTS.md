# デッドコードと関連テストの洗い出し

## 概要

Clean Architecture 移行に伴い、コントローラは Interactor + Presenter 経由でレスポンスするようになった。  
その結果、**HtmlCrudResponder** と **ApiCrudResponder** が提供する `respond_to_*` 系メソッドは、どのコントローラからも呼ばれていない（デッドコード）。

本ドキュメントは、そのデッドコードと、それに紐づくテストを一覧し、対応方針を記す。

---

## 1. デッドコード一覧

### 1.1 HtmlCrudResponder

| ファイル | メソッド | 説明 |
|----------|----------|------|
| `app/controllers/concerns/html_crud_responder.rb` | `respond_to_create` | create 用の redirect/render ヘルパー。**未使用** |
| 同上 | `respond_to_update` | update 用の redirect/render ヘルパー。**未使用** |

**根拠**: `app/controllers` および `lib/` を grep した結果、上記メソッドの**呼び出しは 0 件**（定義とコメント内の使用例のみ）。  
`AgriculturalTasksController`, `CropsController`, `FertilizesController`, `PesticidesController` はすべて Interactor + Presenter で create/update を処理しており、`respond_to_create` / `respond_to_update` は使っていない。

### 1.2 ApiCrudResponder

| ファイル | メソッド | 説明 |
|----------|----------|------|
| `app/controllers/concerns/api_crud_responder.rb` | `respond_to_create` | API create 用の render ヘルパー。**未使用** |
| 同上 | `respond_to_update` | API update 用の render ヘルパー。**未使用** |
| 同上 | `respond_to_destroy` | API destroy 用の head/render ヘルパー。**未使用** |
| 同上 | `respond_to_show` | API show 用の render ヘルパー。**未使用** |
| 同上 | `respond_to_index` | API index 用の render ヘルパー。**未使用** |

**根拠**: `Api::V1::Masters::FarmsController` および `Api::V1::Masters::CropsController` は Interactor + Presenter + `render_response` のみで index/show/create/update/destroy を実装しており、上記 5 メソッドの**呼び出しは 0 件**。

---

## 2. 関連テストの洗い出し

### 2.1 HtmlCrudResponder 関連

| テストファイル | テスト名 | 内容 | デッドコードとの関係 |
|----------------|----------|------|----------------------|
| `test/controllers/concerns/html_crud_responder_test.rb` | `HtmlCrudResponder is defined` | モジュールが定義されていることを確認 | デッドコード削除後も有効（Concern 自体は残す場合） |
| 同上 | `HtmlCrudResponder provides respond_to_create method` | **private に `respond_to_create` が存在することを検証** | **デッドコードの「存在」のみをテスト**。メソッド削除で失敗 |
| 同上 | `HtmlCrudResponder provides respond_to_update method` | **private に `respond_to_update` が存在することを検証** | **デッドコードの「存在」のみをテスト**。メソッド削除で失敗 |

その他、次のコントローラテストで **include していることだけ**を検証している（Concern のメソッドは呼んでいない）:

- `test/controllers/agricultural_tasks_controller_test.rb` — "includes HtmlCrudResponder"
- `test/controllers/crops_controller_test.rb` — "includes HtmlCrudResponder"
- `test/controllers/fertilizes_controller_test.rb` — "includes HtmlCrudResponder"
- `test/controllers/pesticides_controller_test.rb` — "includes HtmlCrudResponder"

→ これらは「Concern を include している」という契約のテスト。デッドメソッドを削除しても **include は残る**ため、テストはそのままでよい。

### 2.2 ApiCrudResponder 関連

| テストファイル | テスト名 | 内容 | デッドコードとの関係 |
|----------------|----------|------|----------------------|
| `test/controllers/concerns/api_crud_responder_test.rb` | `FarmsController includes ApiCrudResponder` | Concern の include を確認 | デッドコード削除後も有効 |
| 同上 | `respond_to_index renders json array` | **FarmsController#index の HTTP 動作**（GET → JSON 配列） | 名前は Concern のメソッドだが、**実装は Interactor+Presenter**。デッドメソッド削除でも **テストは通る** |
| 同上 | `respond_to_show renders json object` | **FarmsController#show の HTTP 動作** | 同上 |
| 同上 | `respond_to_create with valid params ...` | **FarmsController#create の HTTP 動作** | 同上 |
| 同上 | `respond_to_create with invalid params ...` | **FarmsController#create の 422 動作** | 同上 |
| 同上 | `respond_to_update with valid params ...` | **FarmsController#update の HTTP 動作** | 同上 |
| 同上 | `respond_to_update with invalid params ...` | **FarmsController#update の 422 動作** | 同上 |
| 同上 | `respond_to_destroy with valid params ...` | **FarmsController#destroy の undo JSON** | 同上 |

→ ApiCrudResponderTest は **Concern のメソッドを直接呼んでいない**。FarmsController の統合テストであり、デッドメソッド（respond_to_*）を削除しても **テストはそのまま通る**。  
テスト名が `respond_to_*` になっているだけなので、必要なら「FarmsController の index/show/create/update/destroy」などにリネームすると分かりやすい。

### 2.3 その他の「include のみ」テスト

- `test/controllers/api/v1/masters/crops_controller_test.rb` — "includes ApiCrudResponder"
- `test/controllers/pests_controller_test.rb` — "does not include HtmlCrudResponder"
- `test/controllers/fields_controller_test.rb` — "does not include HtmlCrudResponder"

→ デッドコード削除の有無に依存しない。

---

## 3. 対応方針の推奨

### 3.1 デッドコードの削除

- **HtmlCrudResponder**: `respond_to_create` と `respond_to_update` を削除する。
  - 両方削除するとモジュールが空になるため、**HtmlCrudResponder は「空の Concern」として残す**か、**include を各コントローラから外す**かのどちらか。
  - 将来の共通化の受け皿として残すなら、モジュール定義だけ残してメソッド削除でよい。

- **ApiCrudResponder**: `respond_to_create` / `respond_to_update` / `respond_to_destroy` / `respond_to_show` / `respond_to_index` の 5 メソッドを削除する。
  - 同様に、空の Concern として残すか、include をやめるか選択。

### 3.2 テストの修正

| 対象 | 対応 |
|------|------|
| `test/controllers/concerns/html_crud_responder_test.rb` | 「provides respond_to_create / respond_to_update」の **2 テストを削除**。モジュール定義テストは残す（Concern を残す場合）。 |
| `test/controllers/concerns/api_crud_responder_test.rb` | **テストの削除は不要**。デッドメソッドを消しても FarmsController の統合テストとして成立。任意でテスト名を「FarmsController ...」に変更可。 |
| 各コントローラの「includes HtmlCrudResponder / ApiCrudResponder」テスト | Concern を残す限り **変更不要**。Concern 自体を削除する場合は、include を外すのと合わせて当該テストを削除または修正。 |

### 3.3 まとめ

1. **デッドコード**: HtmlCrudResponder の 2 メソッド、ApiCrudResponder の 5 メソッドを削除してよい。
2. **テストで修正が必要なのは**: `HtmlCrudResponderTest` の「respond_to_create / respond_to_update が存在する」の 2 件のみ。これらはデッドコードの存在検査なので、メソッド削除に合わせて削除する。
3. **ApiCrudResponderTest** は実質 FarmsController の統合テストのため、デッドコード削除だけなら修正不要。

---

## 4. 参照

- コントローラの実装: いずれも Interactor + Presenter で create/update/destroy を処理。
- grep 結果: `respond_to_create` / `respond_to_update` 等の**呼び出し**は app/lib に 0 件（定義とコメント除く）。
