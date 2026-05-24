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

        # @return [Hash] { ok: true, row: Hash } | { ok: false, errors: Array<String> }
        def update_masters_crop_task_template_for_api(crop_id:, template_id:, attributes:)
          raise NotImplementedError, "Subclasses must implement update_masters_crop_task_template_for_api"
        end

        def delete_masters_crop_task_template!(crop_id:, template_id:)
          raise NotImplementedError, "Subclasses must implement delete_masters_crop_task_template!"
        end

        def find_crop_show_detail(crop_id)
          raise NotImplementedError, "Subclasses must implement find_crop_show_detail"
        end

        # @return [Domain::Crop::Entities::CropEntity]
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # AI 害虫の affected_crops 名前フォールバック用。
        # @return [Integer, nil]
        def resolve_crop_id_by_name(user_id:, crop_name:)
          raise NotImplementedError, "Subclasses must implement resolve_crop_id_by_name"
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
