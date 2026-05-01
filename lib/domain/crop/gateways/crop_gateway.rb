# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      class CropGateway
        class << self
          def default
            @default ||= Adapters::Crop::Gateways::CropMemoryGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

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

        # HTML 画面用: 認可＋表示に必要な関連を includes して1回取得
        def find_authorized_model_for_html(user, id, for_edit:)
          raise NotImplementedError, "Subclasses must implement find_authorized_model_for_html"
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

        def soft_destroy_with_undo(user:, crop_id:, auto_hide_after:, translator:)
          raise NotImplementedError, "Subclasses must implement soft_destroy_with_undo"
        end
      end
    end
  end
end
