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

        # @param is_reference [Boolean]
        # @param region [String, nil]
        # @return [Array<Domain::Crop::Entities::CropEntity>]
        def list_by_is_reference(is_reference:, region: nil)
          raise NotImplementedError, "Subclasses must implement list_by_is_reference"
        end

        # @return [Array<Domain::Crop::Entities::CropEntity>]
        def list_by_user_id(user_id:, region: nil)
          raise NotImplementedError, "Subclasses must implement list_by_user_id"
        end

        # エントリスケジュール: agrr requirement 組み立て用に AR を逐次 yield（Relation は公開しない）
        # エントリスケジュール一覧: region のみで AR を逐次 yield（参照可否は Interactor + Policy）
        def each_crop_record_with_stages_by_region(region, &block)
          raise NotImplementedError, "Subclasses must implement each_crop_record_with_stages_by_region"
        end

        # エントリスケジュール最適化用: id のみで AR を includes 付き取得（参照可否は Interactor + Policy）
        def find_crop_record_with_stages!(crop_id)
          raise NotImplementedError, "Subclasses must implement find_crop_record_with_stages!"
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

        # @return [Domain::Crop::Entities::CropEntity]
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # @param ids [Array<Integer, String>]
        # @return [Array<Domain::Crop::Entities::CropEntity>] ids の順序で存在する行のみ
        def list_by_ids(ids)
          raise NotImplementedError, "Subclasses must implement list_by_ids"
        end

        # @param name [String]
        # @return [Array<Domain::Crop::Entities::CropEntity>]
        def list_by_name(name:)
          raise NotImplementedError, "Subclasses must implement list_by_name"
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
