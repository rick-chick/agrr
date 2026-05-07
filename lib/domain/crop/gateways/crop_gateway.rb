# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropGateway
        def list
          raise NotImplementedError, "Subclasses must implement list"
        end

        def find_by_id(crop_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        def create(create_input_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def update(crop_id, update_input_dto)
          raise NotImplementedError, "Subclasses must implement update"
        end

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

        def list_crop_stages_by_crop_id(crop_id)
          raise NotImplementedError, "Subclasses must implement list_crop_stages_by_crop_id"
        end

        def find_crop_stage_by_id(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_crop_stage_by_id"
        end

        # TemperatureRequirement methods
        def find_temperature_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_temperature_requirement"
        end

        def create_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_temperature_requirement"
        end

        def update_temperature_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_temperature_requirement"
        end

        # ThermalRequirement methods
        def find_thermal_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_thermal_requirement"
        end

        def create_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_thermal_requirement"
        end

        def update_thermal_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_thermal_requirement"
        end

        # SunshineRequirement methods
        def find_sunshine_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_sunshine_requirement"
        end

        def create_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_sunshine_requirement"
        end

        def update_sunshine_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_sunshine_requirement"
        end

        # NutrientRequirement methods
        def find_nutrient_requirement(crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_nutrient_requirement"
        end

        def create_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement create_nutrient_requirement"
        end

        def update_nutrient_requirement(crop_stage_id, requirement_dto)
          raise NotImplementedError, "Subclasses must implement update_nutrient_requirement"
        end

        # Policy 連携（永続化は Adapter）。一覧は Entity 配列のみ公開
        def list_index_for_user(user)
          raise NotImplementedError, "Subclasses must implement list_index_for_user"
        end

        def list_user_owned_non_reference_crops_ordered_by_name(user)
          raise NotImplementedError, "Subclasses must implement list_user_owned_non_reference_crops_ordered_by_name"
        end

        def list_user_owned_non_reference_crops_by_ids(user, ids)
          raise NotImplementedError, "Subclasses must implement list_user_owned_non_reference_crops_by_ids"
        end

        # マスター系 HTML/API: 自ユーザーの非参照作物を id で取得（失敗時 RecordNotFound）
        def find_user_non_reference_crop_for_masters!(user, crop_id)
          raise NotImplementedError, "Subclasses must implement find_user_non_reference_crop_for_masters!"
        end

        # 個人計画 API 等: 自ユーザーの非参照作物を id で取得（なければ nil）。戻りは永続レコード。
        def find_user_non_reference_crop_record(user, crop_id)
          raise NotImplementedError, "Subclasses must implement find_user_non_reference_crop_record"
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

        def find_authorized_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_view"
        end

        def find_authorized_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_for_edit"
        end

        def find_authorized_model_for_view(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_view"
        end

        def find_authorized_model_for_edit(user, id)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_edit"
        end

        # 認可済み作物を一度読み、Entity と永続モデル（連鎖プリロード済み）を束ねる（Controller の二重取得防止）。
        def find_authorized_crop_loaded_bundle!(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_loaded_bundle!"
        end

        # マスター HTML/API: 非参照作物に属する CropStage を取得（子が無い場合は RecordNotFound）。
        def find_masters_crop_stage_in_crop_for_user!(user, crop_id, crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_masters_crop_stage_in_crop_for_user!"
        end

        # マスター: 作物と CropStage を一度の作物読み込みで束ねる（before_action 二重取得の回避）。
        def find_masters_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id)
          raise NotImplementedError, "Subclasses must implement find_masters_crop_with_crop_stage_bundle!"
        end

        # マスター API: 非参照作物に属する CropTaskTemplate を取得。
        def find_masters_crop_task_template_in_crop_for_user!(user, crop_id, template_id)
          raise NotImplementedError, "Subclasses must implement find_masters_crop_task_template_in_crop_for_user!"
        end

        # マスター: 作物と CropTaskTemplate を一度の作物読み込みで束ねる。
        def find_masters_crop_with_task_template_bundle!(user, crop_id, template_id)
          raise NotImplementedError, "Subclasses must implement find_masters_crop_with_task_template_bundle!"
        end

        # マスター API: 作物と農業タスクの関連付けを作成。
        def create_masters_crop_task_template_association(user, input_dto)
          raise NotImplementedError, "Subclasses must implement create_masters_crop_task_template_association"
        end

        # 認可済み作物に属する CropStage を取得（for_edit に応じて view/edit 認可）。
        def find_authorized_crop_stage_in_crop!(user, crop_id, crop_stage_id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_stage_in_crop!"
        end

        # 認可済み作物と CropStage を一度の作物読み込みで束ねる。
        def find_authorized_crop_with_crop_stage_bundle!(user, crop_id, crop_stage_id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_with_crop_stage_bundle!"
        end

        # マスター API: 作物に紐づく農業タスクテンプレート一覧 JSON 行（永続はゲートウェイ内のみ）
        def masters_crop_agricultural_task_templates_index_rows(user:, crop_id:)
          raise NotImplementedError, "Subclasses must implement masters_crop_agricultural_task_templates_index_rows"
        end

        # 作物にネストしたタスク関連付け: 未関連付けの農業タスクを picklist 用に id/name の Hash 配列で返す（作物解決は find_user_non_reference_crop_for_masters! と同一）
        def selectable_agricultural_task_picklist_rows_for_nested_templates(user:, crop_id:)
          raise NotImplementedError, "Subclasses must implement selectable_agricultural_task_picklist_rows_for_nested_templates"
        end

        # @return [Hash] { ok: true, row: Hash } | { ok: false, errors: Array<String> }
        def update_masters_crop_task_template_for_api(user:, crop_id:, template_id:, attributes:)
          raise NotImplementedError, "Subclasses must implement update_masters_crop_task_template_for_api"
        end

        def destroy_masters_crop_task_template_for_api!(user:, crop_id:, template_id:)
          raise NotImplementedError, "Subclasses must implement destroy_masters_crop_task_template_for_api!"
        end

        # 認可済み作物に属する CropTaskScheduleBlueprint を取得。
        # 親作物は view 認可（set_crop と整合）。変更系は update/delete 用ゲートウェイが find_authorized_model_for_edit で統一する。
        def find_authorized_crop_task_schedule_blueprint_in_crop!(user, crop_id, blueprint_id)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_task_schedule_blueprint_in_crop!"
        end

        # 認可済み作物に属する CropTaskTemplate を取得。
        def find_authorized_crop_task_template_in_crop!(user, crop_id, template_id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_task_template_in_crop!"
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

        # Crops::TaskScheduleBlueprintsController — 削除後の crop 再読込と UI 用データ
        def reload_crop_after_task_schedule_blueprint_delete!(crop:, blueprint_id_for_response:)
          raise NotImplementedError, "Subclasses must implement reload_crop_after_task_schedule_blueprint_delete!"
        end

        # 認可済み作物を関連プリロード付き CropEntity で返す（詳細フォーム・マスタの親コンテキスト等）。
        # for_edit が真なら編集許可のみ、偽なら参照許可のみで評価する。
        def find_authorized_crop_entity_with_association_preloads(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_crop_entity_with_association_preloads"
        end

        def find_model(id)
          raise NotImplementedError, "Subclasses must implement find_model"
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

        def soft_destroy_with_undo(user:, crop_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
