ruby: warning: shebang line ending with \r may cause problems
# Masters CRUD parity matrix (generated)

Generated: 2026-05-30T12:29:23Z

| Layer | Count |
|-------|------:|
| GW | 62 |
| R1 | 298 |
| R4 | 145 |
| **Total** | **505** |

Status: added=161, partial=0, pending=344

| Layer | Master | Source | Ruby path | Ruby test | Rust path | Rust fn | Status |
|-------|--------|--------|-----------|-----------|-----------|---------|--------|
| R1 | shared | domain | `test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb` | valid api key resolves via api key gateway |  |  | pending |
| R1 | shared | domain | `test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb` | invalid api key notifies invalid key |  |  | pending |
| R1 | shared | domain | `test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb` | no api key uses session gateway when authenticated |  |  | pending |
| R1 | shared | domain | `test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb` | no api key and anonymous session requires login |  |  | pending |
| R1 | shared | domain | `test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb` | whitespace only api key skips api key gateway and uses session |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | creates fertilize for a regular user and passes the entity to on_success |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | creates a reference fertilize for an admin user |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | rejects a reference fertilize requested by a non-admin user |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | calls on_failure with the policy exception when the gateway denies permission |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | calls on_failure with Error when create raises RecordInvalid |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | calls on_failure with name is required when gateway rejects blank name |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | re-raises unexpected gateway errors |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_create_interactor_test.rb` | calls on_failure when the user cannot be resolved |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_list_interactor_test.rb` | call passes fertilize entities to output port |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_list_interactor_test.rb` | call forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_list_interactor_test.rb` | propagates unexpected StandardError from gateway |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb` | call passes fertilize detail dto to output port |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb` | propagates unexpected StandardError from gateway |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb` | call maps RecordNotFound to translated not_found flash |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb` | call forwards PolicyPermissionDenied to on_failure |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | should update fertilize successfully for regular user |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | should call on_failure with policy when interactor denies edit |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | should raise error when non-admin user tries to change is_reference flag |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | should allow admin user to change is_reference flag |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | should handle update failure |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | propagates StandardError when user lookup raises |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_update_interactor_test.rb` | on_failure includes fertilize_id from input when entity lookup fails before update |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_destroy_interactor_test.rb` | calls on_success when delete is allowed |  |  | pending |
| R1 | fertilize | domain | `test/domain/fertilize/interactors/fertilize_destroy_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_create_interactor_test.rb` | 一般ユーザーが参照害虫を作成しようとすると on_failure（reference_only_admin） |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_create_interactor_test.rb` | admin は参照害虫を作成でき on_success |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_create_interactor_test.rb` | 一般ユーザーの非参照害虫作成は呼び出しユーザー所有で on_success |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_create_interactor_test.rb` | create の RecordInvalid 時は Error を返す |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_create_interactor_test.rb` | 一般ユーザーの region 指定は Policy により破棄される |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_list_interactor_test.rb` | call loads pests using policy-built filter for regular user |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_list_interactor_test.rb` | call loads pests using policy-built filter for admin |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_list_interactor_test.rb` | call maps RecordInvalid to failure Error |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_detail_interactor_test.rb` | calls on_success with detail dto when view is allowed |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_detail_interactor_test.rb` | calls on_failure with no_permission when view is denied |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_update_interactor_test.rb` | on_failure returns Error when update raises RecordInvalid |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_update_interactor_test.rb` | propagates StandardError when user lookup raises |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_update_interactor_test.rb` | calls on_failure with PolicyPermissionDenied when edit is denied |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_update_interactor_test.rb` | 一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only） |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_destroy_interactor_test.rb` | calls on_success when delete is allowed |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_destroy_interactor_test.rb` | calls on_failure when pesticides block delete |  |  | pending |
| R1 | pest | domain | `test/domain/pest/interactors/pest_destroy_interactor_test.rb` | calls on_failure with Error when permission denied |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb` | calls on_pest_not_found when find_by_id raises RecordNotFound |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb` | calls on_success when pest is found, selectable, and association is created |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb` | calls on_already_associated when association already exists |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb` | calls on_forbidden when crop is not associable with pest per CropPolicy |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_destroy_interactor_test.rb` | calls on_not_associated when association is missing |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_destroy_interactor_test.rb` | calls on_success when association exists and delete succeeds |  |  | pending |
| R1 | crop_pests | domain | `test/domain/pest/interactors/masters_crop_pests_index_interactor_test.rb` | on_success filters crop pests by selectable list policy |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_create_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_create_interactor_test.rb` | calls on_failure with Error when non-admin requests reference pesticide |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_list_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb` | calls on_success with detail dto when view is allowed |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb` | calls on_failure with policy exception when reference pesticide is not visible |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb` | calls on_failure with policy exception when other user pesticide |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_update_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_update_interactor_test.rb` | calls on_failure with Error when non-admin toggles is_reference |  |  | pending |
| R1 | pesticide | domain | `test/domain/pesticide/interactors/pesticide_destroy_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb` | 一般ユーザーが参照作業を作成しようとすると on_failure（reference_only_admin） |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb` | admin は参照作業を作成でき on_success |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb` | 一般ユーザーの非参照作業作成は呼び出しユーザー所有で on_success |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb` | 同名がスコープ内に存在すると on_failure（name taken） |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb` | 一般ユーザーの region 指定は Policy により破棄される |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb` | non-admin: calls list_user_owned_tasks |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb` | admin with no filter (defaults to all): calls list_user_and_reference_tasks |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb` | admin filter=reference: calls list_reference_tasks |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb` | forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb` | forwards RecordNotFound to on_failure as Error |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_detail_interactor_test.rb` | calls on_success with detail dto when read gateway returns wire |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_detail_interactor_test.rb` | calls on_failure with policy exception when permission is denied |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb` | calls on_success when gateway updates |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb` | calls on_failure with policy_exception when permission is denied |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb` | 一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only） |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb` | 同名がスコープ内に存在すると on_failure（name taken） |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb` | selected_crop_ids があるとき Policy と Gateway でテンプレート同期する |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_destroy_interactor_test.rb` | calls on_success when gateway returns success |  |  | pending |
| R1 | agricultural_task | domain | `test/domain/agricultural_task/interactors/agricultural_task_destroy_interactor_test.rb` | calls on_failure with policy exception when permission is denied |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_create_interactor_test.rb` | calls on_success when gateway returns entity |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_create_interactor_test.rb` | calls on_failure with error dto when non-admin requests reference crop |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_create_interactor_test.rb` | calls on_failure with limit exceeded dto when at crop limit |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_create_interactor_test.rb` | skips crop limit check for reference crop create by admin |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_list_interactor_test.rb` | call loads crops using policy-built filter for regular user |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_list_interactor_test.rb` | call loads crops using policy-built filter for admin |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_list_interactor_test.rb` | call maps RecordNotFound to failure Error |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_detail_interactor_test.rb` | calls on_success with crop detail dto when read gateway returns wire |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_detail_interactor_test.rb` | calls on_failure with policy exception when permission is denied |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_update_interactor_test.rb` | calls on_success when gateway returns entity |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_update_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_update_interactor_test.rb` | calls on_failure with error dto when non-admin toggles is_reference |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_destroy_interactor_test.rb` | calls on_success when gateway returns success |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_destroy_interactor_test.rb` | calls on_failure with policy exception when permission is denied |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_destroy_interactor_test.rb` | calls on_failure when cultivation plan crops block delete |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_create_interactor_test.rb` | should create crop stage successfully |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_create_interactor_test.rb` | calls on_failure with Error when gateway raises RecordInvalid |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_create_interactor_test.rb` | propagates StandardError when gateway raises |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_list_interactor_test.rb` | calls on_success with crop stages when gateway succeeds |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_list_interactor_test.rb` | calls on_failure with Error when gateway raises RecordInvalid |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_list_interactor_test.rb` | propagates StandardError when gateway raises |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_detail_interactor_test.rb` | calls on_success with crop stage when gateway succeeds |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_detail_interactor_test.rb` | calls on_failure with Error when gateway raises RecordInvalid |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_detail_interactor_test.rb` | propagates StandardError when gateway raises |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_update_interactor_test.rb` | calls on_success with updated crop stage when gateway succeeds |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_update_interactor_test.rb` | calls on_failure with Error when gateway raises RecordInvalid |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_update_interactor_test.rb` | propagates StandardError when gateway raises |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_delete_interactor_test.rb` | calls on_success with delete result when gateway succeeds |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_delete_interactor_test.rb` | calls on_failure with Error when gateway raises RecordInvalid |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_stage_delete_interactor_test.rb` | propagates StandardError when gateway raises |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_load_masters_authorized_crop_stage_interactor_test.rb` | returns bundle when crop and stage match |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_load_user_non_reference_for_masters_interactor_test.rb` | calls on_success when gateway returns crop |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_load_user_non_reference_for_masters_interactor_test.rb` | calls on_not_found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should create association successfully |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when agricultural_task_id missing |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when crop not found |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when agricultural task not found |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when association is forbidden |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when association is duplicate |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb` | should return failure when validation fails |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_index_interactor_test.rb` | should return rows successfully |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb` | should return updated row successfully |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb` | should return validation_failed when gateway returns ok false |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb` | should return association_not_found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_destroy_interactor_test.rb` | should succeed when gateway destroys |  |  | pending |
| R1 | crop | domain | `test/domain/crop/interactors/crop_masters_task_template_destroy_interactor_test.rb` | should return association_not_found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | renders show success when requirement exists |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | renders not found when requirement missing |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | creates when absent and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | reports already exists when requirement present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | reports validation errors on RecordInvalid |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | updates when present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | not found when missing before update |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | destroys and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb` | not found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | renders show success when requirement exists |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | renders not found when requirement missing |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | creates when absent and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | reports already exists when requirement present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | reports validation errors on RecordInvalid |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | updates when present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | not found when missing before update |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | destroys and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb` | not found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | renders show success when requirement exists |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | renders not found when requirement missing |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | creates when absent and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | reports already exists when requirement present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | reports validation errors on RecordInvalid |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | updates when present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | not found when missing before update |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | destroys and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb` | not found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | renders show success when requirement exists |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | renders not found when requirement missing |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | creates when absent and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | reports already exists when requirement present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | reports validation errors on RecordInvalid |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | updates when present |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | not found when missing before update |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | destroys and reports success |  |  | pending |
| R1 | crop_requirements | domain | `test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb` | not found when gateway raises RecordNotFound |  |  | pending |
| R1 | crop_pesticides | domain | `test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb` | on_success lists pesticides for authorized crop |  |  | pending |
| R1 | crop_pesticides | domain | `test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb` | on_not_found when crop is reference only |  |  | pending |
| R1 | crop_pesticides | domain | `test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb` | on_not_found when crop missing |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_create_interactor_test.rb` | calls on_success when under farm limit |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_create_interactor_test.rb` | calls on_failure with limit exceeded dto when at farm limit |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_list_interactor_test.rb` | calls list_user_owned_farms and on_success with empty reference_farms for regular user |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_list_interactor_test.rb` | calls list_user_and_reference_farms and list_reference_farms for admin |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_list_interactor_test.rb` | forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_detail_interactor_test.rb` | calls on_success when read gateway returns wire |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_detail_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_update_interactor_test.rb` | calls on_success when gateway returns entity |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_update_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_destroy_interactor_test.rb` | should destroy farm successfully when no crop plans exist |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_destroy_interactor_test.rb` | calls on_failure when free crop plans block delete |  |  | pending |
| R1 | farm | domain | `test/domain/farm/interactors/farm_destroy_interactor_test.rb` | calls on_failure when policy permission denied |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_list_interactor_test.rb` | call passes FarmFieldsList to output port on success |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_list_interactor_test.rb` | call forwards RecordNotFound to on_failure as Error |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_list_interactor_test.rb` | call forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_detail_interactor_test.rb` | call passes FieldWithFarm to output port on success |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_detail_interactor_test.rb` | call forwards RecordNotFound to on_failure as FieldDetailFailure with farm_id |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_update_interactor_test.rb` | call passes FieldEntity to output port on success |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_update_interactor_test.rb` | call forwards RecordNotFound to on_failure as Error |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_update_interactor_test.rb` | call forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_destroy_interactor_test.rb` | call passes FieldDestroyOutput to output port on success |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_destroy_interactor_test.rb` | call forwards RecordNotFound to on_failure as Error |  |  | pending |
| R1 | field | domain | `test/domain/field/interactors/field_destroy_interactor_test.rb` | call forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb` | 一般ユーザーが参照ルールを作成しようとすると on_failure（reference_only_admin） |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb` | admin は参照ルールを作成でき on_success |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb` | 一般ユーザーの非参照ルール作成は呼び出しユーザー所有で on_success |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb` | 一般ユーザーの region 指定は Policy により破棄される |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb` | admin の region 指定は保持される |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_list_interactor_test.rb` | call passes rules from gateway to output port on success |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_list_interactor_test.rb` | forwards policy permission denied to on_failure as exception |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_detail_interactor_test.rb` | calls on_failure with policy exception when permission denied |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb` | calls on_failure with policy exception when interactor denies edit |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb` | 一般ユーザーが is_reference フラグを変更しようとすると on_failure（reference_flag_admin_only） |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb` | admin の region 更新は Policy により保持される |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb` | 一般ユーザーの region 更新は Policy により破棄される |  |  | pending |
| R1 | interaction_rule | domain | `test/domain/interaction_rule/interactors/interaction_rule_destroy_interactor_test.rb` | calls on_failure with policy exception when interactor denies destroy |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | duplicate_name_record? は既存なしなら false |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | duplicate_name_record? は作成時に既存があれば true |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | duplicate_name_record? は更新時に同一 ID なら false |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | duplicate_name_record? は更新時に別 ID なら true |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_assignment_allowed? は非参照なら誰でも true |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_assignment_allowed? は参照付与を admin のみ許可する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_flag_change_allowed? は変更なし（requested == current）なら true |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_flag_change_allowed? はフラグ変更を admin のみ許可する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | create 正規化: admin の参照レコードは user_id=nil / is_reference=true |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | create 正規化: admin の非参照レコードは呼び出しユーザー所有 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | create 正規化: 一般ユーザーは常に非参照・自身所有へ強制される |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | create 正規化: region は admin のみ保持、一般ユーザーは破棄 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | create 正規化: admin_forced は admin と同等に扱う |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | update 正規化: region は admin のみ保持、一般ユーザーは破棄 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | update 正規化: 参照化は user_id=nil、参照解除は操作ユーザーを設定 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | update 正規化: is_reference に変更が無ければそのキーを落とす |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_record_user_id_valid? は参照なら user_id nil のみ許可 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/referencable_resource_policy_test.rb` | reference_record_user_id_valid? は非参照なら user_id 必須 |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | normalize_attrs_for_create for regular user |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | view_allowed? for own non-reference |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | view_allowed? denies reference for non-admin |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/fertilize_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | normalize_attrs_for_create for regular user forces non-reference |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | view_allowed? for reference pest |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | selectable_list_filter is reference_or_owned for regular user |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | selectable_for_user? allows reference and own pests |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pest_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | normalize_attrs_for_create for regular user |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | view_allowed? uses referencable rule |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/pesticide_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_create for admin with reference crop |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_create for admin with user crop (non-reference) |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_create for regular user always creates non-reference crop owned by user |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | view_allowed? for admin |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | view_allowed? for reference crop |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | view_allowed? for own crop |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | view_allowed? denies other user non-reference crop |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | edit_allowed? for own non-reference |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | ReferencableResourcePolicy visible_for_user? matches referencable list rule |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/crop_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | normalize_attrs_for_create for regular user |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | masters_crop_task_template_associate_allowed? allows reference task for another owner |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | masters_crop_task_template_associate_allowed? allows own non-reference task |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | masters_crop_task_template_associate_allowed? rejects other user non-reference task |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | view_allowed? for own task |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/agricultural_task_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | normalize_attrs_for_create sets user and non-reference |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | view_allowed? for admin |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | view_allowed? for reference farm |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | edit_allowed? for own non-reference |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/farm_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_create は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_create は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_create は参照ルールを user_id=nil にする |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_create は非参照ルールを呼び出しユーザー所有にする |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_update は admin の region を保持する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_update は一般ユーザーの region を破棄する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_update は参照化のとき user_id を nil にする |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | normalize_attrs_for_update は参照解除のとき user_id を操作ユーザーにする |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | view_allowed? は admin と所有者に許可する |  |  | pending |
| R1 | shared | domain | `test/domain/shared/policies/interaction_rule_policy_test.rb` | edit_allowed? は一般ユーザーの参照ルール編集を拒否する |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_create_limit_policy_test.rb` | limit_exceeded? is false for reference crop regardless of count |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_create_limit_policy_test.rb` | limit_exceeded? is false below max for user crop |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_create_limit_policy_test.rb` | limit_exceeded? is true at max for user crop |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_create_limit_policy_test.rb` | limit_exceeded? is true above max for user crop |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_destroy_policy_test.rb` | blocked_reason is cultivation_plan when plan crops exist |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_destroy_policy_test.rb` | blocked_reason is other when free crop plans exist |  |  | pending |
| R1 | crop | domain | `test/domain/crop/policies/crop_destroy_policy_test.rb` | blocked_reason is nil when no associations |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_create_limit_policy_test.rb` | limit_exceeded? is false below max |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_create_limit_policy_test.rb` | limit_exceeded? is false at max minus one |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_create_limit_policy_test.rb` | limit_exceeded? is true at max |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_create_limit_policy_test.rb` | limit_exceeded? is true above max |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_destroy_policy_test.rb` | blocked_reason is nil when no free crop plans |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_destroy_policy_test.rb` | blocked_reason is free_crop_plans when count positive |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_reference_ownership_policy_test.rb` | reference_farm_user_valid? は非参照農場なら常に true |  |  | pending |
| R1 | farm | domain | `test/domain/farm/policies/farm_reference_ownership_policy_test.rb` | reference_farm_user_valid? は参照農場はアノニマス所有者のみ |  |  | pending |
| R1 | pest | domain | `test/domain/pest/policies/pest_destroy_policy_test.rb` | blocked_reason is nil when no pesticides |  |  | pending |
| R1 | pest | domain | `test/domain/pest/policies/pest_destroy_policy_test.rb` | blocked_reason is pesticides_in_use when count positive |  |  | pending |
| GW | fertilize | ar | `test/adapters/fertilize/gateways/fertilize_active_record_gateway_test.rb` | list_index_for_filter returns only named user-owned non-reference fertilizes for regular user | crates/agrr-adapters-sqlite/src/fertilize/fertilize_gateway_test.rs |  | added |
| GW | fertilize | ar | `test/adapters/fertilize/gateways/fertilize_active_record_gateway_test.rb` | list_index_for_filter for admin includes reference and own user-owned rows | crates/agrr-adapters-sqlite/src/fertilize/fertilize_gateway_test.rs |  | added |
| GW | pest | ar | `test/adapters/pest/gateways/pest_active_record_gateway_list_index_test.rb` | list_index_for_filter owned_non_reference returns only that user | crates/agrr-adapters-sqlite/src/pest/pest_gateway_test.rs |  | added |
| GW | pest | ar | `test/adapters/pest/gateways/pest_active_record_gateway_list_index_test.rb` | list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id | crates/agrr-adapters-sqlite/src/pest/pest_gateway_test.rs |  | added |
| GW | crop_pests | ar | `test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb` | create links crop and pest | crates/agrr-adapters-sqlite/src/pest/crop_pest_gateway_test.rs |  | added |
| GW | crop_pests | ar | `test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb` | find_by_crop_id_and_pest_id returns link entity when present | crates/agrr-adapters-sqlite/src/pest/crop_pest_gateway_test.rs |  | added |
| GW | crop_pests | ar | `test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb` | list_by_pest_id returns linked crop ids | crates/agrr-adapters-sqlite/src/pest/crop_pest_gateway_test.rs |  | added |
| GW | crop_pests | ar | `test/adapters/pest/gateways/crop_pest_active_record_gateway_test.rb` | delete removes association | crates/agrr-adapters-sqlite/src/pest/crop_pest_gateway_test.rs |  | added |
| GW | pest | ar | `test/adapters/pesticide/gateways/pesticide_active_record_gateway_test.rb` | list_index_for_filter owned_non_reference returns only that user | crates/agrr-adapters-sqlite/src/pesticide/pesticide_gateway_test.rs |  | added |
| GW | pest | ar | `test/adapters/pesticide/gateways/pesticide_active_record_gateway_test.rb` | list_by_crop_id_for_filter scopes by crop and filter mode | crates/agrr-adapters-sqlite/src/pesticide/pesticide_gateway_test.rs |  | added |
| GW | pest | ar | `test/adapters/pesticide/gateways/pesticide_active_record_gateway_test.rb` | list_index_for_filter reference_or_owned includes reference and admin-owned rows | crates/agrr-adapters-sqlite/src/pesticide/pesticide_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | create_crop_stage creates a new crop stage | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | update_crop_stage updates an existing crop stage | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | delete_crop_stage deletes an existing crop stage | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | find_by_crop_stage_id returns temperature requirement if exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | find_by_crop_stage_id returns nil if not exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | create_temperature_requirement creates a new requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | update_temperature_requirement updates existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | thermal find_by_crop_stage_id returns requirement if exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | create_thermal_requirement creates a new requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | update_thermal_requirement updates existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | sunshine find_by_crop_stage_id returns requirement if exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | create_sunshine_requirement creates a new requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | update_sunshine_requirement updates existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | nutrient find_by_crop_stage_id returns requirement if exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | create_nutrient_requirement creates a new requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | update_nutrient_requirement updates existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | delete_temperature_requirement deletes existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | delete_thermal_requirement deletes existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | delete_sunshine_requirement deletes existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | delete_nutrient_requirement deletes existing requirement | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | list_index_for_filter owned_non_reference returns only that user | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | list_by_ids returns entities in requested order for existing ids | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop | ar | `test/adapters/crop/gateways/crop_active_record_gateway_test.rb` | list_index_for_filter reference_or_owned returns reference rows and rows owned by user_id | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop_stages | ar | `test/adapters/crop/gateways/crop_stage_active_record_gateway_test.rb` | find_by_id returns crop stage entity when record exists | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | crop_stages | ar | `test/adapters/crop/gateways/crop_stage_active_record_gateway_test.rb` | find_by_id raises RecordNotFound when missing | crates/agrr-adapters-sqlite/src/crop/crop_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | list_user_and_reference_farms includes user farm and reference farm | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | list_user_owned_farms excludes reference farms | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | should find farm by id | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | should raise domain RecordNotFound when farm not found | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | should create farm | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | should update farm | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | list_reference_farms returns all reference farm entities | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | list_user_owned_farms returns only user non-reference farms | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | farm_weather_data_access_context_for_owned_farm returns dto for owner | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | farm_weather_data_access_context_for_owned_farm returns nil for other users farm | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | farm | ar | `test/adapters/farm/gateways/farm_active_record_gateway_test.rb` | farm_weather_data_access_context_for_admin_lookup returns any farm by id | crates/agrr-adapters-sqlite/src/farm/farm_gateway_test.rs |  | added |
| GW | field | ar | `test/adapters/field/gateways/field_active_record_gateway_test.rb` | get_total_area_by_farm_id sums field areas | crates/agrr-adapters-sqlite/src/field/field_gateway_test.rs |  | added |
| GW | field | ar | `test/adapters/field/gateways/field_active_record_gateway_test.rb` | farm_fields_list returns fields for farm | crates/agrr-adapters-sqlite/src/field/field_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should find by id and return entity | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should raise when not found | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should create and return entity | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should raise when create fails validation - invalid region | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should update and return entity | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should raise when update fails validation - invalid region | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should list all records and return entities | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | should list with scope and return entities | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | list_index_for_filter returns scoped entities for non-admin | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | list_index_for_filter for admin includes reference and own rows | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | interaction_rule | ar | `test/adapters/interaction_rule/gateways/interaction_rule_active_record_gateway_test.rb` | list_by_cultivation_plan_id returns entities for plan farm region | crates/agrr-adapters-sqlite/src/interaction_rule/interaction_rule_gateway_test.rs |  | added |
| GW | crop_ag_templates | ar | `test/adapters/agricultural_task/gateways/crop_task_template_active_record_gateway_test.rb` | create_detail persists template with given attributes | crates/agrr-adapters-sqlite/src/crop/crop_masters_task_template_gateway.rs |  | added |
| GW | crop_ag_templates | ar | `test/adapters/agricultural_task/gateways/crop_task_template_active_record_gateway_test.rb` | create_detail raises record invalid when validation fails | crates/agrr-adapters-sqlite/src/crop/crop_masters_task_template_gateway.rs |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/agricultural_tasks_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/agricultural_tasks_controller_test.rb` | should show agricultural_task | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/agricultural_tasks_controller_test.rb` | should create agricultural_task | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/agricultural_tasks_controller_test.rb` | should update agricultural_task | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/agricultural_tasks_controller_test.rb` | should destroy agricultural_task | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_extract_api_key_test.rb` | accepts api key from Authorization Bearer header | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_extract_api_key_test.rb` | accepts api key from query parameter | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_test.rb` | rejects request without api key or session | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_test.rb` | rejects request with invalid API key | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_test.rb` | allows request with valid API key in X-API-Key header | test/contract/masters_* |  | added |
| R4 | auth | controller | `test/controllers/api/v1/masters/base_controller_test.rb` | allows request with valid session cookie | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb` | should create association |  |  | pending |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb` | should create association with default values |  |  | pending |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb` | should update template |  |  | pending |
| R4 | crop_ag_tasks | controller | `test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb` | should destroy association |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | create should return created with valid params |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | create should return bad_request with invalid params |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | create should return bad_request without required params |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | should return unauthorized when not logged in |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | should return not_found for other user |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | index should return crop stages for valid crop |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | index should return not_found for non-existent crop |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | show should return crop stage with valid id |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | update should modify crop stage with valid params |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | admin can create crop stage for reference crop |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | update should return bad_request with invalid params |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | destroy should delete crop stage |  |  | pending |
| R4 | crop_stages | controller | `test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb` | destroy should return not_found with invalid crop_stage id |  |  | pending |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/crops/pesticides_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/crops/pesticides_controller_test.rb` | should not include other user |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should create association |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not create association with reference pest for user crop |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not create association without pest_id |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not create association with non-existent pest |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not create association with other user |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not create duplicate association |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should destroy association |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not destroy non-existent association |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/crops/pests_controller_test.rb` | should not destroy association for other user |  |  | pending |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should show crop with name and crop_stages in json | test/contract/masters_* |  | added |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should not create reference crop as non-admin |  |  | pending |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should create crop | test/contract/masters_* |  | added |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should not create crop with invalid params |  |  | pending |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should update crop | test/contract/masters_* |  | added |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should destroy crop | test/contract/masters_* |  | added |
| R4 | crops | controller | `test/controllers/api/v1/masters/crops_controller_test.rb` | should return 422 when destroying crop that is in use (cultivation_plan_crops) |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | admin should get index with reference farms |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should return forbidden on index when gateway denies policy |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should show farm |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should create farm | test/contract/masters_* |  | added |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should update farm | test/contract/masters_* |  | added |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should return unprocessable_entity when create farm with invalid params |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should return unprocessable_entity when update farm with invalid name |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | should destroy farm | test/contract/masters_* |  | added |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | destroy returns 422 when farm has free_crop_plans |  |  | pending |
| R4 | farms | controller | `test/controllers/api/v1/masters/farms_controller_test.rb` | cannot access other user |  |  | pending |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | should show fertilize | test/contract/masters_* |  | added |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | create returns 422 when name is missing | test/contract/masters_* |  | added |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | should create fertilize | test/contract/masters_* |  | added |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | should update fertilize | test/contract/masters_* |  | added |
| R4 | fertilizes | controller | `test/controllers/api/v1/masters/fertilizes_controller_test.rb` | should destroy fertilize | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should return forbidden when listing fields for another users farm | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should show field | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should create field | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should update field | test/contract/masters_* |  | added |
| R4 | fields | controller | `test/controllers/api/v1/masters/fields_controller_test.rb` | should destroy field | test/contract/masters_* |  | added |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should return forbidden on index when gateway denies policy |  |  | pending |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should show interaction_rule | test/contract/masters_* |  | added |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should not show other user |  |  | pending |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should create interaction_rule | test/contract/masters_* |  | added |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should not create reference interaction_rule as non-admin |  |  | pending |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should not toggle is_reference as non-admin via API |  |  | pending |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | should update interaction_rule | test/contract/masters_* |  | added |
| R4 | interaction_rules | controller | `test/controllers/api/v1/masters/interaction_rules_controller_test.rb` | destroy_returns_undo_token_json_via_masters_api | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/pesticides_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/pesticides_controller_test.rb` | should show pesticide | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/pesticides_controller_test.rb` | should create pesticide | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/pesticides_controller_test.rb` | should update pesticide | test/contract/masters_* |  | added |
| R4 | crop_pesticides | controller | `test/controllers/api/v1/masters/pesticides_controller_test.rb` | should destroy pesticide | test/contract/masters_* |  | added |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | should get index | test/contract/masters_* |  | added |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | index returns 422 when a pest has blank name |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | should show pest |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | create returns 422 when name is missing | test/contract/masters_* |  | added |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | should create pest |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | should update pest |  |  | pending |
| R4 | crop_pests | controller | `test/controllers/api/v1/masters/pests_controller_test.rb` | should destroy pest |  |  | pending |
| R4 | contract | contract | `test/contract/masters_agricultural_tasks_contract_test.rb` | should get index | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_agricultural_tasks_contract_test.rb` | should show agricultural_task | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_agricultural_tasks_contract_test.rb` | should create agricultural_task | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_agricultural_tasks_contract_test.rb` | should update agricultural_task | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_agricultural_tasks_contract_test.rb` | should destroy agricultural_task | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | rejects request without api key or session | agrr-server (contract) |  | added |R1=298 GW=62 R4=145 total=505

| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | rejects request with invalid API key | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | allows request with valid API key in X-API-Key header | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | allows request with valid session cookie | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | accepts api key from Authorization Bearer header | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_auth_contract_test.rb` | accepts api key from query parameter | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crop_nested_contract_test.rb` | get crop pests index includes associated pest | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crop_nested_contract_test.rb` | post crop pest association returns created shape | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crop_nested_contract_test.rb` | get crop agricultural_tasks index returns array | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crop_nested_contract_test.rb` | get crop pesticides index returns array | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crop_nested_contract_test.rb` | delete crop pest association returns no content | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crops_contract_test.rb` | crops index returns user crops | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crops_contract_test.rb` | should show crop with name and crop_stages in json | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crops_contract_test.rb` | should create crop | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crops_contract_test.rb` | should update crop | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_crops_contract_test.rb` | should destroy crop | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_farms_contract_test.rb` | farms index returns user farms | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_farms_contract_test.rb` | farms show returns farm with fields array | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_farms_contract_test.rb` | should create farm | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_farms_contract_test.rb` | should update farm | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_farms_contract_test.rb` | should destroy farm | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | should get index | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | should show fertilize | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | create returns 422 when name is missing | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | should create fertilize | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | should update fertilize | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fertilizes_contract_test.rb` | should destroy fertilize | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should get index for farm fields | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should return forbidden when listing fields for another users farm | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should show field | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should create field | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should update field | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_fields_contract_test.rb` | should destroy field | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_interaction_rules_contract_test.rb` | should get index | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_interaction_rules_contract_test.rb` | should show interaction_rule | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_interaction_rules_contract_test.rb` | should create interaction_rule | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_interaction_rules_contract_test.rb` | should update interaction_rule | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_interaction_rules_contract_test.rb` | destroy_returns_undo_token_json_via_masters_api | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_patch_contract_test.rb` | patch masters pest updates name | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_patch_contract_test.rb` | patch masters crop stage updates name | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pesticides_contract_test.rb` | should get index | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pesticides_contract_test.rb` | should show pesticide | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pesticides_contract_test.rb` | should create pesticide | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pesticides_contract_test.rb` | should update pesticide | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pesticides_contract_test.rb` | should destroy pesticide | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pests_contract_test.rb` | post create and get show return flat pest with name | agrr-server (contract) |  | added |
| R4 | contract | contract | `test/contract/masters_pests_contract_test.rb` | index lists created pest name at top level | agrr-server (contract) |  | added |
