# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropGateway
        # CropStage methods
        def create_crop_stage(crop_stage_dto)
          raise NotImplementedError, "Subclasses must implement create_crop_stage"
        end

        def update_crop_stage(crop_stage_id, crop_stage_dto)
          raise NotImplementedError, "Subclasses must implement update_crop_stage"
        end

        def delete_crop_stage(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_crop_stage"
        end

        def list_by_crop_id(crop_id)
          raise NotImplementedError, "Subclasses must implement list_by_crop_id"
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_temperature_requirement"
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_temperature_requirement"
        end

        def delete_temperature_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_temperature_requirement"
        end

        # ThermalRequirement methods
        def create_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_thermal_requirement"
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_thermal_requirement"
        end

        def delete_thermal_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_thermal_requirement"
        end

        # SunshineRequirement methods
        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_sunshine_requirement"
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_sunshine_requirement"
        end

        def delete_sunshine_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_sunshine_requirement"
        end

        # NutrientRequirement methods
        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_nutrient_requirement"
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_nutrient_requirement"
        end

        def delete_nutrient_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement delete_nutrient_requirement"
        end

        # Policy 連携（永続化は Adapter）。一覧は Entity 配列のみ公開
        # @param filter [Domain::Shared::ValueObjects::ReferenceIndexListFilter]
        def list_index_for_filter(filter)
          raise NotImplementedError, "Subclasses must implement list_index_for_filter"
        end

        def list_user_owned_non_reference_crops_ordered_by_name(user)
          raise NotImplementedError, "Subclasses must implement list_user_owned_non_reference_crops_ordered_by_name"
        end

        # 農業作業マスタ編集: 指定ユーザーの非参照作物を名前順で列挙（任意で地域で絞る）
        def list_non_reference_crops_for_user_id_ordered(user_id, region = nil)
          raise NotImplementedError, "Subclasses must implement list_non_reference_crops_for_user_id_ordered"
        end

        # 公開栽培計画 REST add_crop: 参照作物レコードを id で解決（なければ nil）
        def find_reference_crop_record_for_public_plan_add_crop(crop_id)
          raise NotImplementedError, "Subclasses must implement find_reference_crop_record_for_public_plan_add_crop"
        end

        def list_reference_crop_entities(region: nil)
          raise NotImplementedError, "Subclasses must implement list_reference_crop_entities"
        end

        # エントリスケジュール: Crop#to_agrr_requirement 用に AR を逐次 yield（Relation は公開しない）
        def each_reference_crop_for_entry_schedule(region, &block)
          raise NotImplementedError, "Subclasses must implement each_reference_crop_for_entry_schedule"
        end

        def find_reference_crop_for_entry_schedule!(region, crop_id)
          raise NotImplementedError, "Subclasses must implement find_reference_crop_for_entry_schedule!"
        end

        # 認可は Interactor（ReferenceRecordAuthorization）。永続読み込みのみ。
        def find_crop_loaded_bundle!(id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_crop_loaded_bundle!"
        end

        # マスタCRUD: HTML 新規フォーム用の空スナップショット（永続化しない）
        # @return [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def blank_crop_master_form_snapshot
          raise NotImplementedError, "Subclasses must implement blank_crop_master_form_snapshot"
        end

        # マスタCRUD: update 失敗時の再描画用に認可済み作物へパラメータをマージ（永続化しない）
        # @return [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def merge_edit_crop_params_for_master_form!(user:, crop_id:, attributes:)
          raise NotImplementedError, "Subclasses must implement merge_edit_crop_params_for_master_form!"
        end

        # マスター API: 作物と農業タスクの関連付けを作成。
        def create_masters_crop_task_template_association(input_dto)
          raise NotImplementedError, "Subclasses must implement create_masters_crop_task_template_association"
        end

        def find_crop_with_crop_stage_bundle!(crop_id, crop_stage_id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_crop_with_crop_stage_bundle!"
        end

        # マスター API: 作物に紐づく農業タスクテンプレート一覧 JSON 行（永続はゲートウェイ内のみ）
        def masters_crop_agricultural_task_templates_index_rows(crop_id:)
          raise NotImplementedError, "Subclasses must implement masters_crop_agricultural_task_templates_index_rows"
        end

        # 作物にネストしたタスク関連付け: 未関連付けの農業タスクを picklist 用に id/name の Hash 配列で返す（作物の編集認可は Interactor 側）
        def selectable_agricultural_task_picklist_rows_for_nested_templates(user:, crop_id:)
          raise NotImplementedError, "Subclasses must implement selectable_agricultural_task_picklist_rows_for_nested_templates"
        end

        # @return [Hash] { ok: true, row: Hash } | { ok: false, errors: Array<String> }
        def update_masters_crop_task_template_for_api(crop_id:, template_id:, attributes:)
          raise NotImplementedError, "Subclasses must implement update_masters_crop_task_template_for_api"
        end

        def delete_masters_crop_task_template!(crop_id:, template_id:)
          raise NotImplementedError, "Subclasses must implement delete_masters_crop_task_template!"
        end

        def find_crop_task_template_in_crop!(crop_id, template_id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_crop_task_template_in_crop!"
        end

        # ブループリント削除（app/services へ委譲）。RecordNotFound はここで握りつぶし not_found を返す。
        def delete_task_schedule_blueprint_bundle_in_crop!(user, crop_id, blueprint_id)
          raise NotImplementedError, "Subclasses must implement delete_task_schedule_blueprint_bundle_in_crop!"
        end

        # Crops::TaskScheduleBlueprintsController — 位置更新（実装は AR アダプタで例外を吸収し Hash を返す）
        def update_task_schedule_blueprint_position_mutation(crop:, blueprint:, gdd_trigger:, priority:)
          raise NotImplementedError, "Subclasses must implement update_task_schedule_blueprint_position_mutation"
        end

        # 編集認可済み作物＋ブループリント ID で位置更新（Interactor は user_id / ID のみ渡す）
        def update_task_schedule_blueprint_position_for_user(user:, crop_id:, blueprint_id:, gdd_trigger:, priority:)
          raise NotImplementedError, "Subclasses must implement update_task_schedule_blueprint_position_for_user"
        end

        # Crops::TaskScheduleBlueprintsController — 削除後の crop 読取と UI 用データ
        def find_by_crop_id(crop_id:, blueprint_id_for_response:)
          raise NotImplementedError, "Subclasses must implement find_by_crop_id"
        end

        def find_crop_show_detail(crop_id)
          raise NotImplementedError, "Subclasses must implement find_crop_show_detail"
        end

        # @return [Domain::Crop::Entities::CropEntity]
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def count_user_owned_non_reference_crops(user_id:)
          raise NotImplementedError, "Subclasses must implement count_user_owned_non_reference_crops"
        end

        def create_for_user(user, attrs)
          raise NotImplementedError, "Subclasses must implement create_for_user"
        end

        def update_for_user(user, id, attrs)
          raise NotImplementedError, "Subclasses must implement update_for_user"
        end

        # エントリスケジュール: StageRoleResolver / WindowService 用にステージ＋温度要件を純データで返す（N+1 回避で includes 済み想定）
        def entry_schedule_ordered_stage_rows(crop_id:)
          raise NotImplementedError, "Subclasses must implement entry_schedule_ordered_stage_rows"
        end

        # @return [Domain::Crop::Dtos::CropDeleteUsage]
        def find_delete_usage(crop_id)
          raise NotImplementedError, "Subclasses must implement find_delete_usage"
        end

        def soft_delete_with_undo(user:, crop_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_delete_with_undo"
        end
      end
    end
  end
end
