# 契約: AgriculturalTask Update — 参照フラグ変更時の作物関連付け

Rails の AgriculturalTasksController#update において、参照フラグ（is_reference）変更時に Interactor が is_reference/user_id を更新し、そのうえで作物紐付け（CropTaskTemplate）が「許可された作物のみ」になるよう振る舞いを規定する契約。**Rails（テスト）が正**とする。

## 1. スコープ・正とする仕様（Rails）

- **正**: `test/controllers/agricultural_tasks_controller_test.rb` の以下 2 テストが期待する挙動。
- **対象**: PATCH /agricultural_tasks/:id（HTML）、Interactor の update、および update_crop_task_templates。

## 2. 期待される振る舞い（Rails テストから抽出）

### 2.1 管理者が参照フラグを有効に変更するとユーザー作物の関連付けが解除される

- **前提**: 管理者が、自身のユーザー所有タスク（is_reference: false）にユーザー作物を紐付けた状態。
- **操作**: そのタスクを `is_reference: true` に更新し、params に `selected_crop_ids: [user_crop.id]` を送る。
- **期待**:
  - タスクが参照タスクになる: `task.is_reference? == true`, `task.user_id == nil`。
  - **タスクに紐づく作物が空になる**: `task.crops` が空（参照タスクは「参照作物のみ」紐付け可のため、ユーザー作物は許可されず紐付け解除）。

### 2.2 参照フラグ変更後は許可された作物のみ関連付けられる

- **前提**: 管理者が、参照タスク（is_reference: true）に参照作物を紐付けた状態。
- **操作**: そのタスクを `is_reference: false` に更新し、params に `selected_crop_ids: [reference_crop.id, user_crop.id]` を送る。
- **期待**:
  - タスクがユーザー所有になる: `task.is_reference? == false`, `task.user_id == current_user.id`。
  - **タスクに紐づく作物は「そのユーザーの作物」のみ**: `task.crops.pluck(:id) == [user_crop.id]`（参照作物は許可されず除外）。

## 3. 許可作物のルール（Rails に合わせる）

| タスクの状態 | 紐付けを許可する作物 |
|--------------|----------------------|
| is_reference: true | 参照作物のみ（Crop.where(is_reference: true)） |
| is_reference: false | そのタスクの user_id に属するユーザー作物のみ（Crop.where(is_reference: false, user_id: task.user_id)） |

地域（region）がタスクに設定されている場合は、上記に加えて task.region と一致する作物に限定する（既存 `accessible_crops_for_selection` と同様）。

## 4. データフロー（契約）

1. **Controller**: `task_attributes` に `is_reference` を含め、`AgriculturalTaskUpdateInputDto.from_hash({ agricultural_task: task_attributes }, id)` で DTO を組み立てる。
2. **AgriculturalTaskUpdateInputDto**: `is_reference` を保持する（attr_reader / initialize / from_hash）。
3. **AgriculturalTaskUpdateInteractor**: DTO の `is_reference` を `attrs` に含め、`AgriculturalTaskPolicy.apply_update!(user, task_model, attrs)` に渡す。Policy が is_reference/user_id を更新する。
4. **Controller**: Interactor 成功後に **@agricultural_task.reload** し、更新後の is_reference/user_id を反映する。
5. **Controller**: `update_crop_task_templates(selected_crop_ids)` 内で、**selected_crop_ids を「現在のタスク（reload 後）に対して許可された作物」に限定**してから、CropTaskTemplate の追加・削除を行う。
   - 許可 crop_id 一覧: `accessible_crops_for_selection(@agricultural_task).where(id: selected_crop_ids).pluck(:id)` と同等の算出。
   - その一覧と現在の紐付けを比較し、追加・削除のみ行う（既存ロジックの対象を「許可された id のみ」に制限）。

## 5. 実装チェックリスト

- [x] AgriculturalTaskUpdateInputDto に `is_reference` を追加し、from_hash で `agricultural_task[:is_reference]` を渡す。
- [x] AgriculturalTaskUpdateInteractor で `attrs[:is_reference]` を設定し（present または key がある場合）、Policy.apply_update! に渡す。
- [x] AgriculturalTasksController#update で、interactor.call 成功後に `@agricultural_task.reload` する。
- [x] update_crop_task_templates の先頭で、selected_crop_ids を「@agricultural_task（reload 後）に対して許可された作物」にフィルタし、その id 一覧を使って追加・削除する。
- [x] 上記 2 テストがパスする。

## 6. 参照

- テスト: `test/controllers/agricultural_tasks_controller_test.rb`（管理者が参照フラグを有効に… / 参照フラグ変更後は許可された作物のみ…）
- コントローラ: `app/controllers/agricultural_tasks_controller.rb`（update, update_crop_task_templates, accessible_crops_for_selection）
- Policy: `lib/domain/shared/policies/agricultural_task_policy.rb`（apply_update!）
- Interactor: `lib/domain/agricultural_task/interactors/agricultural_task_update_interactor.rb`
- DTO: `lib/domain/agricultural_task/dtos/agricultural_task_update_input_dto.rb`
