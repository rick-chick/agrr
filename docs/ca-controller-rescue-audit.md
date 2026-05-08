# CA: controller `rescue` / `rescue_from` 監査（禁止 17 関連）

更新: 計画「CA 違反 一覧と計画的対応」フェーズ 0 成果物。

凡例:

- **DEAD**: Interactor が `StandardError` または `PolicyPermissionDenied` 等を捕捉し Port に渡すため、アクション直下の `rescue` は到達しない。
- **LIVE**: 例外がコントローラまで上がる想定内パスがある、またはインフラ境界のみ。
- **REFACTOR**: Interactor + Presenter へ失敗を移す必要あり（禁止 17 の本扱い）。

## API


| 場所                                                 | 種別                                   | 分類       | メモ                                                                                                |
| -------------------------------------------------- | ------------------------------------ | -------- | ------------------------------------------------------------------------------------------------- |
| `api/v1/masters/base_controller.rb`                | `rescue_from PolicyPermissionDenied` | **DEAD** | Masters の各 Interactor が `StandardError` / 明示 rescue で捕捉。`PolicyPermissionDenied < StandardError`。 |
| `api/v1/public_plans/entry_schedule_controller.rb` | `decode_entry_cursor` の狭い `rescue`   | **ガード**  | 不正カーソルは `nil`。アクションは Interactor + Presenter。                                                      |
| `api/v1/plans_controller.rb`                       | （該当なし）                               | **—**    | Interactor + Presenter、`rescue` なし（2026-05-06 確認）。                                                |
| `api/v1/contact_messages_controller.rb`            | （該当なし）                               | **DEAD** | reCAPTCHA / レート制限は Interactor + Presenter `on_failure`（2026-05-06）。                               |


## HTML / 一般


| 場所                                                                                                                                              | 分類            | メモ                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------- | ------------- | --------------------------------------------------------------------------------- |
| `farms_controller.rb` (html index/show/create/update)                                                                                           | **DEAD**      | `Farm*Interactor` が `StandardError` 等を捕捉到達しない。                                    |
| `crops_controller.rb`, `pests_controller.rb`, `fertilizes_controller.rb`, `agricultural_tasks_controller.rb`, `interaction_rules_controller.rb` | **DEAD 候補**   | 各 `*Interactor#call` が `rescue StandardError` + `on_failure` なら同様。アクションごとに確認して除去。 |
| `plans_controller.rb`, `crops/task_schedule_blueprints_controller.rb`                                                                           | **要確認**       | Interactor パターン確認後 DEAD または REFACTOR。                                             |
| `plans/task_schedule_items_controller.rb`                                                                                                       | **DEAD 寄り**   | Interactor + Presenter、`rescue` / `rescue_from` なし（2026-05-06 確認）。                |
| `auth_controller.rb`                                                                                                                            | **要確認**       | 認証フロー。インフラ的 rescue の可能性。                                                          |
| ~~`concerns/deletion_undo_flow.rb`~~, ~~`agrr_optimization.rb`~~                                                                                  | **撤去済み**    | 2026-05 時点でリポジトリに存在しない。削除 Undo は Interactor + Presenter / [`application_controller.rb`](../app/controllers/application_controller.rb) の `render_deletion_undo_*`、agrr は `CompositionRoot`・[`app/gateways/agrr/`](../app/gateways/agrr/) 経由。禁止 17 の追加監査は現行コントローラを対象にする。 |


## Gateway 境界（禁止 PageDto 参照）


| 場所                                                                                 | 分類                   |
| ---------------------------------------------------------------------------------- | -------------------- |
| `lib/adapters/cultivation_plan/gateways/cultivation_plan_active_record_gateway.rb` | **REFACTOR**（フェーズ 6） |
| `lib/adapters/farm/gateways/farm_active_record_gateway.rb`                         | **REFACTOR**（フェーズ 6） |
