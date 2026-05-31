# Masters parity — remaining coverage (generated)

Generated: 2026-05-30T12:29:32Z

Rows still **pending** in `MASTERS-PARITY-MATRIX.md` (344 total).
B2: each row is addressed in a follow-up PR (test + implementation GREEN per master).

| Layer | Master | Ruby path | Ruby test |
|-------|--------|-----------|-----------|
| R1 | shared | ``test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb`` | valid api key resolves via api key gateway |
| R1 | shared | ``test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb`` | invalid api key notifies invalid key |
| R1 | shared | ``test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb`` | no api key uses session gateway when authenticated |
| R1 | shared | ``test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb`` | no api key and anonymous session requires login |
| R1 | shared | ``test/domain/shared/interactors/masters_api_credentials_resolve_interactor_test.rb`` | whitespace only api key skips api key gateway and uses session |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | creates fertilize for a regular user and passes the entity to on_success |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | creates a reference fertilize for an admin user |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | rejects a reference fertilize requested by a non-admin user |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | calls on_failure with the policy exception when the gateway denies permission |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | calls on_failure with Error when create raises RecordInvalid |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | calls on_failure with name is required when gateway rejects blank name |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | re-raises unexpected gateway errors |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_create_interactor_test.rb`` | calls on_failure when the user cannot be resolved |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_list_interactor_test.rb`` | call passes fertilize entities to output port |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_list_interactor_test.rb`` | call forwards policy permission denied to on_failure as exception |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_list_interactor_test.rb`` | propagates unexpected StandardError from gateway |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb`` | call passes fertilize detail dto to output port |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb`` | propagates unexpected StandardError from gateway |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb`` | call maps RecordNotFound to translated not_found flash |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_detail_interactor_test.rb`` | call forwards PolicyPermissionDenied to on_failure |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | should update fertilize successfully for regular user |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | should call on_failure with policy when interactor denies edit |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | should raise error when non-admin user tries to change is_reference flag |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | should allow admin user to change is_reference flag |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | should handle update failure |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | propagates StandardError when user lookup raises |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_update_interactor_test.rb`` | on_failure includes fertilize_id from input when entity lookup fails before update |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_destroy_interactor_test.rb`` | calls on_success when delete is allowed |
| R1 | fertilize | ``test/domain/fertilize/interactors/fertilize_destroy_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | pest | ``test/domain/pest/interactors/pest_create_interactor_test.rb`` | 一般ユーザーが参照害虫を作成しようとすると on_failure（reference_only_admin） |
| R1 | pest | ``test/domain/pest/interactors/pest_create_interactor_test.rb`` | admin は参照害虫を作成でき on_success |
| R1 | pest | ``test/domain/pest/interactors/pest_create_interactor_test.rb`` | 一般ユーザーの非参照害虫作成は呼び出しユーザー所有で on_success |
| R1 | pest | ``test/domain/pest/interactors/pest_create_interactor_test.rb`` | create の RecordInvalid 時は Error を返す |
| R1 | pest | ``test/domain/pest/interactors/pest_create_interactor_test.rb`` | 一般ユーザーの region 指定は Policy により破棄される |
| R1 | pest | ``test/domain/pest/interactors/pest_list_interactor_test.rb`` | call loads pests using policy-built filter for regular user |
| R1 | pest | ``test/domain/pest/interactors/pest_list_interactor_test.rb`` | call loads pests using policy-built filter for admin |
| R1 | pest | ``test/domain/pest/interactors/pest_list_interactor_test.rb`` | call maps RecordInvalid to failure Error |
| R1 | pest | ``test/domain/pest/interactors/pest_detail_interactor_test.rb`` | calls on_success with detail dto when view is allowed |
| R1 | pest | ``test/domain/pest/interactors/pest_detail_interactor_test.rb`` | calls on_failure with no_permission when view is denied |
| R1 | pest | ``test/domain/pest/interactors/pest_update_interactor_test.rb`` | on_failure returns Error when update raises RecordInvalid |
| R1 | pest | ``test/domain/pest/interactors/pest_update_interactor_test.rb`` | propagates StandardError when user lookup raises |
| R1 | pest | ``test/domain/pest/interactors/pest_update_interactor_test.rb`` | calls on_failure with PolicyPermissionDenied when edit is denied |
| R1 | pest | ``test/domain/pest/interactors/pest_update_interactor_test.rb`` | 一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only） |
| R1 | pest | ``test/domain/pest/interactors/pest_destroy_interactor_test.rb`` | calls on_success when delete is allowed |
| R1 | pest | ``test/domain/pest/interactors/pest_destroy_interactor_test.rb`` | calls on_failure when pesticides block delete |
| R1 | pest | ``test/domain/pest/interactors/pest_destroy_interactor_test.rb`` | calls on_failure with Error when permission denied |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb`` | calls on_pest_not_found when find_by_id raises RecordNotFound |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb`` | calls on_success when pest is found, selectable, and association is created |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb`` | calls on_already_associated when association already exists |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_create_interactor_test.rb`` | calls on_forbidden when crop is not associable with pest per CropPolicy |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_destroy_interactor_test.rb`` | calls on_not_associated when association is missing |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_destroy_interactor_test.rb`` | calls on_success when association exists and delete succeeds |
| R1 | crop_pests | ``test/domain/pest/interactors/masters_crop_pests_index_interactor_test.rb`` | on_success filters crop pests by selectable list policy |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_create_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_create_interactor_test.rb`` | calls on_failure with Error when non-admin requests reference pesticide |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_list_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb`` | calls on_success with detail dto when view is allowed |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb`` | calls on_failure with policy exception when reference pesticide is not visible |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_detail_interactor_test.rb`` | calls on_failure with policy exception when other user pesticide |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_update_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_update_interactor_test.rb`` | calls on_failure with Error when non-admin toggles is_reference |
| R1 | pesticide | ``test/domain/pesticide/interactors/pesticide_destroy_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb`` | 一般ユーザーが参照作業を作成しようとすると on_failure（reference_only_admin） |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb`` | admin は参照作業を作成でき on_success |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb`` | 一般ユーザーの非参照作業作成は呼び出しユーザー所有で on_success |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb`` | 同名がスコープ内に存在すると on_failure（name taken） |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_create_interactor_test.rb`` | 一般ユーザーの region 指定は Policy により破棄される |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb`` | non-admin: calls list_user_owned_tasks |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb`` | admin with no filter (defaults to all): calls list_user_and_reference_tasks |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb`` | admin filter=reference: calls list_reference_tasks |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb`` | forwards policy permission denied to on_failure as exception |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_list_interactor_test.rb`` | forwards RecordNotFound to on_failure as Error |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_detail_interactor_test.rb`` | calls on_success with detail dto when read gateway returns wire |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_detail_interactor_test.rb`` | calls on_failure with policy exception when permission is denied |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb`` | calls on_success when gateway updates |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb`` | calls on_failure with policy_exception when permission is denied |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb`` | 一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only） |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb`` | 同名がスコープ内に存在すると on_failure（name taken） |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_update_interactor_test.rb`` | selected_crop_ids があるとき Policy と Gateway でテンプレート同期する |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_destroy_interactor_test.rb`` | calls on_success when gateway returns success |
| R1 | agricultural_task | ``test/domain/agricultural_task/interactors/agricultural_task_destroy_interactor_test.rb`` | calls on_failure with policy exception when permission is denied |
| R1 | crop | ``test/domain/crop/interactors/crop_create_interactor_test.rb`` | calls on_success when gateway returns entity |
| R1 | crop | ``test/domain/crop/interactors/crop_create_interactor_test.rb`` | calls on_failure with error dto when non-admin requests reference crop |
| R1 | crop | ``test/domain/crop/interactors/crop_create_interactor_test.rb`` | calls on_failure with limit exceeded dto when at crop limit |
| R1 | crop | ``test/domain/crop/interactors/crop_create_interactor_test.rb`` | skips crop limit check for reference crop create by admin |
| R1 | crop | ``test/domain/crop/interactors/crop_list_interactor_test.rb`` | call loads crops using policy-built filter for regular user |
| R1 | crop | ``test/domain/crop/interactors/crop_list_interactor_test.rb`` | call loads crops using policy-built filter for admin |
| R1 | crop | ``test/domain/crop/interactors/crop_list_interactor_test.rb`` | call maps RecordNotFound to failure Error |
| R1 | crop | ``test/domain/crop/interactors/crop_detail_interactor_test.rb`` | calls on_success with crop detail dto when read gateway returns wire |
| R1 | crop | ``test/domain/crop/interactors/crop_detail_interactor_test.rb`` | calls on_failure with policy exception when permission is denied |
| R1 | crop | ``test/domain/crop/interactors/crop_update_interactor_test.rb`` | calls on_success when gateway returns entity |
| R1 | crop | ``test/domain/crop/interactors/crop_update_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | crop | ``test/domain/crop/interactors/crop_update_interactor_test.rb`` | calls on_failure with error dto when non-admin toggles is_reference |
| R1 | crop | ``test/domain/crop/interactors/crop_destroy_interactor_test.rb`` | calls on_success when gateway returns success |
| R1 | crop | ``test/domain/crop/interactors/crop_destroy_interactor_test.rb`` | calls on_failure with policy exception when permission is denied |
| R1 | crop | ``test/domain/crop/interactors/crop_destroy_interactor_test.rb`` | calls on_failure when cultivation plan crops block delete |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_create_interactor_test.rb`` | should create crop stage successfully |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_create_interactor_test.rb`` | calls on_failure with Error when gateway raises RecordInvalid |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_create_interactor_test.rb`` | propagates StandardError when gateway raises |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_list_interactor_test.rb`` | calls on_success with crop stages when gateway succeeds |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_list_interactor_test.rb`` | calls on_failure with Error when gateway raises RecordInvalid |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_list_interactor_test.rb`` | propagates StandardError when gateway raises |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_detail_interactor_test.rb`` | calls on_success with crop stage when gateway succeeds |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_detail_interactor_test.rb`` | calls on_failure with Error when gateway raises RecordInvalid |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_detail_interactor_test.rb`` | propagates StandardError when gateway raises |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_update_interactor_test.rb`` | calls on_success with updated crop stage when gateway succeeds |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_update_interactor_test.rb`` | calls on_failure with Error when gateway raises RecordInvalid |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_update_interactor_test.rb`` | propagates StandardError when gateway raises |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_delete_interactor_test.rb`` | calls on_success with delete result when gateway succeeds |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_delete_interactor_test.rb`` | calls on_failure with Error when gateway raises RecordInvalid |
| R1 | crop | ``test/domain/crop/interactors/crop_stage_delete_interactor_test.rb`` | propagates StandardError when gateway raises |
| R1 | crop | ``test/domain/crop/interactors/crop_load_masters_authorized_crop_stage_interactor_test.rb`` | returns bundle when crop and stage match |
| R1 | crop | ``test/domain/crop/interactors/crop_load_user_non_reference_for_masters_interactor_test.rb`` | calls on_success when gateway returns crop |
| R1 | crop | ``test/domain/crop/interactors/crop_load_user_non_reference_for_masters_interactor_test.rb`` | calls on_not_found when gateway raises RecordNotFound |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should create association successfully |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when agricultural_task_id missing |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when crop not found |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when agricultural task not found |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when association is forbidden |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when association is duplicate |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_create_interactor_test.rb`` | should return failure when validation fails |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_index_interactor_test.rb`` | should return rows successfully |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb`` | should return updated row successfully |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb`` | should return validation_failed when gateway returns ok false |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_update_interactor_test.rb`` | should return association_not_found when gateway raises RecordNotFound |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_destroy_interactor_test.rb`` | should succeed when gateway destroys |
| R1 | crop | ``test/domain/crop/interactors/crop_masters_task_template_destroy_interactor_test.rb`` | should return association_not_found when gateway raises RecordNotFound |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | renders show success when requirement exists |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | renders not found when requirement missing |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | creates when absent and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | reports already exists when requirement present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | reports validation errors on RecordInvalid |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | updates when present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | not found when missing before update |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | destroys and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_temperature_requirement_api_interactors_test.rb`` | not found when gateway raises RecordNotFound |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | renders show success when requirement exists |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | renders not found when requirement missing |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | creates when absent and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | reports already exists when requirement present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | reports validation errors on RecordInvalid |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | updates when present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | not found when missing before update |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | destroys and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_thermal_requirement_api_interactors_test.rb`` | not found when gateway raises RecordNotFound |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | renders show success when requirement exists |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | renders not found when requirement missing |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | creates when absent and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | reports already exists when requirement present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | reports validation errors on RecordInvalid |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | updates when present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | not found when missing before update |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | destroys and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_sunshine_requirement_api_interactors_test.rb`` | not found when gateway raises RecordNotFound |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | renders show success when requirement exists |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | renders not found when requirement missing |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | creates when absent and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | reports already exists when requirement present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | reports validation errors on RecordInvalid |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | updates when present |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | not found when missing before update |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | destroys and reports success |
| R1 | crop_requirements | ``test/domain/crop/interactors/masters_nutrient_requirement_api_interactors_test.rb`` | not found when gateway raises RecordNotFound |
| R1 | crop_pesticides | ``test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb`` | on_success lists pesticides for authorized crop |
| R1 | crop_pesticides | ``test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb`` | on_not_found when crop is reference only |
| R1 | crop_pesticides | ``test/domain/pesticide/interactors/masters_crop_pesticides_index_interactor_test.rb`` | on_not_found when crop missing |
| R1 | farm | ``test/domain/farm/interactors/farm_create_interactor_test.rb`` | calls on_success when under farm limit |
| R1 | farm | ``test/domain/farm/interactors/farm_create_interactor_test.rb`` | calls on_failure with limit exceeded dto when at farm limit |
| R1 | farm | ``test/domain/farm/interactors/farm_list_interactor_test.rb`` | calls list_user_owned_farms and on_success with empty reference_farms for regular user |
| R1 | farm | ``test/domain/farm/interactors/farm_list_interactor_test.rb`` | calls list_user_and_reference_farms and list_reference_farms for admin |
| R1 | farm | ``test/domain/farm/interactors/farm_list_interactor_test.rb`` | forwards policy permission denied to on_failure as exception |
| R1 | farm | ``test/domain/farm/interactors/farm_detail_interactor_test.rb`` | calls on_success when read gateway returns wire |
| R1 | farm | ``test/domain/farm/interactors/farm_detail_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | farm | ``test/domain/farm/interactors/farm_update_interactor_test.rb`` | calls on_success when gateway returns entity |
| R1 | farm | ``test/domain/farm/interactors/farm_update_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | farm | ``test/domain/farm/interactors/farm_destroy_interactor_test.rb`` | should destroy farm successfully when no crop plans exist |
| R1 | farm | ``test/domain/farm/interactors/farm_destroy_interactor_test.rb`` | calls on_failure when free crop plans block delete |
| R1 | farm | ``test/domain/farm/interactors/farm_destroy_interactor_test.rb`` | calls on_failure when policy permission denied |
| R1 | field | ``test/domain/field/interactors/field_list_interactor_test.rb`` | call passes FarmFieldsList to output port on success |
| R1 | field | ``test/domain/field/interactors/field_list_interactor_test.rb`` | call forwards RecordNotFound to on_failure as Error |
| R1 | field | ``test/domain/field/interactors/field_list_interactor_test.rb`` | call forwards policy permission denied to on_failure as exception |
| R1 | field | ``test/domain/field/interactors/field_detail_interactor_test.rb`` | call passes FieldWithFarm to output port on success |
| R1 | field | ``test/domain/field/interactors/field_detail_interactor_test.rb`` | call forwards RecordNotFound to on_failure as FieldDetailFailure with farm_id |
| R1 | field | ``test/domain/field/interactors/field_update_interactor_test.rb`` | call passes FieldEntity to output port on success |
| R1 | field | ``test/domain/field/interactors/field_update_interactor_test.rb`` | call forwards RecordNotFound to on_failure as Error |
| R1 | field | ``test/domain/field/interactors/field_update_interactor_test.rb`` | call forwards policy permission denied to on_failure as exception |
| R1 | field | ``test/domain/field/interactors/field_destroy_interactor_test.rb`` | call passes FieldDestroyOutput to output port on success |
| R1 | field | ``test/domain/field/interactors/field_destroy_interactor_test.rb`` | call forwards RecordNotFound to on_failure as Error |
| R1 | field | ``test/domain/field/interactors/field_destroy_interactor_test.rb`` | call forwards policy permission denied to on_failure as exception |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb`` | 一般ユーザーが参照ルールを作成しようとすると on_failure（reference_only_admin） |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb`` | admin は参照ルールを作成でき on_success |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb`` | 一般ユーザーの非参照ルール作成は呼び出しユーザー所有で on_success |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb`` | 一般ユーザーの region 指定は Policy により破棄される |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_create_interactor_test.rb`` | admin の region 指定は保持される |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_list_interactor_test.rb`` | call passes rules from gateway to output port on success |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_list_interactor_test.rb`` | forwards policy permission denied to on_failure as exception |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_detail_interactor_test.rb`` | calls on_failure with policy exception when permission denied |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb`` | calls on_failure with policy exception when interactor denies edit |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb`` | 一般ユーザーが is_reference フラグを変更しようとすると on_failure（reference_flag_admin_only） |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb`` | admin の region 更新は Policy により保持される |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_update_interactor_test.rb`` | 一般ユーザーの region 更新は Policy により破棄される |
| R1 | interaction_rule | ``test/domain/interaction_rule/interactors/interaction_rule_destroy_interactor_test.rb`` | calls on_failure with policy exception when interactor denies destroy |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | duplicate_name_record? は既存なしなら false |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | duplicate_name_record? は作成時に既存があれば true |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | duplicate_name_record? は更新時に同一 ID なら false |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | duplicate_name_record? は更新時に別 ID なら true |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_assignment_allowed? は非参照なら誰でも true |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_assignment_allowed? は参照付与を admin のみ許可する |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_flag_change_allowed? は変更なし（requested == current）なら true |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_flag_change_allowed? はフラグ変更を admin のみ許可する |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | create 正規化: admin の参照レコードは user_id=nil / is_reference=true |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | create 正規化: admin の非参照レコードは呼び出しユーザー所有 |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | create 正規化: 一般ユーザーは常に非参照・自身所有へ強制される |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | create 正規化: region は admin のみ保持、一般ユーザーは破棄 |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | create 正規化: admin_forced は admin と同等に扱う |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | update 正規化: region は admin のみ保持、一般ユーザーは破棄 |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | update 正規化: 参照化は user_id=nil、参照解除は操作ユーザーを設定 |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | update 正規化: is_reference に変更が無ければそのキーを落とす |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_record_user_id_valid? は参照なら user_id nil のみ許可 |
| R1 | shared | ``test/domain/shared/policies/referencable_resource_policy_test.rb`` | reference_record_user_id_valid? は非参照なら user_id 必須 |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | normalize_attrs_for_create for regular user |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | view_allowed? for own non-reference |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | view_allowed? denies reference for non-admin |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/fertilize_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | normalize_attrs_for_create for regular user forces non-reference |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | view_allowed? for reference pest |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | selectable_list_filter is reference_or_owned for regular user |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | selectable_for_user? allows reference and own pests |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/pest_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | normalize_attrs_for_create for regular user |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | view_allowed? uses referencable rule |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/pesticide_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_create for admin with reference crop |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_create for admin with user crop (non-reference) |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_create for regular user always creates non-reference crop owned by user |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | view_allowed? for admin |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | view_allowed? for reference crop |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | view_allowed? for own crop |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | view_allowed? denies other user non-reference crop |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | edit_allowed? for own non-reference |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | ReferencableResourcePolicy visible_for_user? matches referencable list rule |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/crop_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | normalize_attrs_for_create for regular user |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | masters_crop_task_template_associate_allowed? allows reference task for another owner |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | masters_crop_task_template_associate_allowed? allows own non-reference task |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | masters_crop_task_template_associate_allowed? rejects other user non-reference task |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | view_allowed? for own task |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/agricultural_task_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | normalize_attrs_for_create sets user and non-reference |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | view_allowed? for admin |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | view_allowed? for reference farm |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | edit_allowed? for own non-reference |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/farm_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_create は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_create は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_create は参照ルールを user_id=nil にする |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_create は非参照ルールを呼び出しユーザー所有にする |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_update は admin の region を保持する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_update は一般ユーザーの region を破棄する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_update は参照化のとき user_id を nil にする |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | normalize_attrs_for_update は参照解除のとき user_id を操作ユーザーにする |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | view_allowed? は admin と所有者に許可する |
| R1 | shared | ``test/domain/shared/policies/interaction_rule_policy_test.rb`` | edit_allowed? は一般ユーザーの参照ルール編集を拒否する |
| R1 | crop | ``test/domain/crop/policies/crop_create_limit_policy_test.rb`` | limit_exceeded? is false for reference crop regardless of count |
| R1 | crop | ``test/domain/crop/policies/crop_create_limit_policy_test.rb`` | limit_exceeded? is false below max for user crop |
| R1 | crop | ``test/domain/crop/policies/crop_create_limit_policy_test.rb`` | limit_exceeded? is true at max for user crop |
| R1 | crop | ``test/domain/crop/policies/crop_create_limit_policy_test.rb`` | limit_exceeded? is true above max for user crop |
| R1 | crop | ``test/domain/crop/policies/crop_destroy_policy_test.rb`` | blocked_reason is cultivation_plan when plan crops exist |
| R1 | crop | ``test/domain/crop/policies/crop_destroy_policy_test.rb`` | blocked_reason is other when free crop plans exist |
| R1 | crop | ``test/domain/crop/policies/crop_destroy_policy_test.rb`` | blocked_reason is nil when no associations |
| R1 | farm | ``test/domain/farm/policies/farm_create_limit_policy_test.rb`` | limit_exceeded? is false below max |
| R1 | farm | ``test/domain/farm/policies/farm_create_limit_policy_test.rb`` | limit_exceeded? is false at max minus one |
| R1 | farm | ``test/domain/farm/policies/farm_create_limit_policy_test.rb`` | limit_exceeded? is true at max |
| R1 | farm | ``test/domain/farm/policies/farm_create_limit_policy_test.rb`` | limit_exceeded? is true above max |
| R1 | farm | ``test/domain/farm/policies/farm_destroy_policy_test.rb`` | blocked_reason is nil when no free crop plans |
| R1 | farm | ``test/domain/farm/policies/farm_destroy_policy_test.rb`` | blocked_reason is free_crop_plans when count positive |
| R1 | farm | ``test/domain/farm/policies/farm_reference_ownership_policy_test.rb`` | reference_farm_user_valid? は非参照農場なら常に true |
| R1 | farm | ``test/domain/farm/policies/farm_reference_ownership_policy_test.rb`` | reference_farm_user_valid? は参照農場はアノニマス所有者のみ |
| R1 | pest | ``test/domain/pest/policies/pest_destroy_policy_test.rb`` | blocked_reason is nil when no pesticides |
| R1 | pest | ``test/domain/pest/policies/pest_destroy_policy_test.rb`` | blocked_reason is pesticides_in_use when count positive |
| R4 | crop_ag_tasks | ``test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb`` | should create association |
| R4 | crop_ag_tasks | ``test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb`` | should create association with default values |
| R4 | crop_ag_tasks | ``test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb`` | should update template |
| R4 | crop_ag_tasks | ``test/controllers/api/v1/masters/crops/agricultural_tasks_controller_test.rb`` | should destroy association |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | create should return created with valid params |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | create should return bad_request with invalid params |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | create should return bad_request without required params |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | should return unauthorized when not logged in |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | should return not_found for other user |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | index should return crop stages for valid crop |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | index should return not_found for non-existent crop |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | show should return crop stage with valid id |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | update should modify crop stage with valid params |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | admin can create crop stage for reference crop |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | update should return bad_request with invalid params |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | destroy should delete crop stage |
| R4 | crop_stages | ``test/controllers/api/v1/masters/crops/crop_stages_controller_test.rb`` | destroy should return not_found with invalid crop_stage id |
| R4 | crop_pesticides | ``test/controllers/api/v1/masters/crops/pesticides_controller_test.rb`` | should not include other user |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should create association |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not create association with reference pest for user crop |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not create association without pest_id |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not create association with non-existent pest |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not create association with other user |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not create duplicate association |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should destroy association |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not destroy non-existent association |
| R4 | crop_pests | ``test/controllers/api/v1/masters/crops/pests_controller_test.rb`` | should not destroy association for other user |
| R4 | crops | ``test/controllers/api/v1/masters/crops_controller_test.rb`` | should not create reference crop as non-admin |
| R4 | crops | ``test/controllers/api/v1/masters/crops_controller_test.rb`` | should not create crop with invalid params |
| R4 | crops | ``test/controllers/api/v1/masters/crops_controller_test.rb`` | should return 422 when destroying crop that is in use (cultivation_plan_crops) |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | admin should get index with reference farms |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | should return forbidden on index when gateway denies policy |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | should show farm |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | should return unprocessable_entity when create farm with invalid params |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | should return unprocessable_entity when update farm with invalid name |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | destroy returns 422 when farm has free_crop_plans |
| R4 | farms | ``test/controllers/api/v1/masters/farms_controller_test.rb`` | cannot access other user |
| R4 | interaction_rules | ``test/controllers/api/v1/masters/interaction_rules_controller_test.rb`` | should return forbidden on index when gateway denies policy |
| R4 | interaction_rules | ``test/controllers/api/v1/masters/interaction_rules_controller_test.rb`` | should not show other user |
| R4 | interaction_rules | ``test/controllers/api/v1/masters/interaction_rules_controller_test.rb`` | should not create reference interaction_rule as non-admin |
| R4 | interaction_rules | ``test/controllers/api/v1/masters/interaction_rules_controller_test.rb`` | should not toggle is_reference as non-admin via API |
| R4 | crop_pests | ``test/controllers/api/v1/masters/pests_controller_test.rb`` | index returns 422 when a pest has blank name |
| R4 | crop_pests | ``test/controllers/api/v1/masters/pests_controller_test.rb`` | should show pest |
| R4 | crop_pests | ``test/controllers/api/v1/masters/pests_controller_test.rb`` | should create pest |
| R4 | crop_pests | ``test/controllers/api/v1/masters/pests_controller_test.rb`` | should update pest |
| R4 | crop_pests | ``test/controllers/api/v1/masters/pests_controller_test.rb`` | should destroy pest |
