# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class CultivationPlanGateway
        class << self
          # @return [CultivationPlanGateway] 既定実装（テストでは {.default=} で差し替え可）
          def default
            @default ||= Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def create(create_dto)
          raise NotImplementedError, "Subclasses must implement create"
        end

        def find_existing(farm, user)
          raise NotImplementedError, "Subclasses must implement find_existing"
        end

        def find_farm(farm_id, user)
          raise NotImplementedError, "Subclasses must implement find_farm"
        end

        def find_crops(crop_ids, user)
          raise NotImplementedError, "Subclasses must implement find_crops"
        end

        def destroy(plan_id, user)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # ID で検索 (Entity または Model を返す)
        def find_by_id(plan_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # phase 更新 proxy (phase_fetching_weather! など)
        def update_phase(plan_id, phase_name, *args)
          raise NotImplementedError, "Subclasses must implement update_phase"
        end

        # TaskSchedule 生成用に CultivationPlan を関連込みで取得
        def find_with_field_cultivations_for_task_schedule(plan_id)
          raise NotImplementedError, "Subclasses must implement find_with_field_cultivations_for_task_schedule"
        end

        # 公開/私有プラン初期化（旧 CultivationPlanInitializeInteractor の永続化部分）
        def initialize_plan_from_selection(farm:, total_area:, crops:, user: nil, session_id: nil, plan_type: "public", plan_year: nil, plan_name: nil, planning_start_date: nil, planning_end_date: nil)
          raise NotImplementedError, "Subclasses must implement initialize_plan_from_selection"
        end

        def within_transaction(&block)
          raise NotImplementedError, "Subclasses must implement within_transaction"
        end

        # 年度指定で既存計画を私有コピー（年度計画フロー）
        def copy_private_plan_for_year(source_plan:, new_year:, user:, session_id: nil)
          raise NotImplementedError, "Subclasses must implement copy_private_plan_for_year"
        end

        def update_predicted_weather_data(cultivation_plan_id, payload)
          raise NotImplementedError, "Subclasses must implement update_predicted_weather_data"
        end

        # --- CultivationPlanOptimizeInteractor 用（永続化は Gateway 経由） ---

        # @return [Boolean]
        def field_cultivations_present?(plan_id)
          raise NotImplementedError, "Subclasses must implement field_cultivations_present?"
        end

        # CultivationPlanCrop を Crop 同梱で返す（to_agrr_requirement 用に crop が必要）
        # @return [Array]
        def cultivation_plan_crops_with_crop(plan_id)
          raise NotImplementedError, "Subclasses must implement cultivation_plan_crops_with_crop"
        end

        def clear_field_cultivations(plan_id)
          raise NotImplementedError, "Subclasses must implement clear_field_cultivations"
        end

        # @param attrs [Hash] FieldCultivation#create! に渡す属性（シンボルキー可）
        # @return 作成された FieldCultivation（AR）
        def create_field_cultivation(plan_id:, attrs:)
          raise NotImplementedError, "Subclasses must implement create_field_cultivation"
        end

        # find_or_create_by!(name:) 相当。圃場レコード id を返す
        def upsert_cultivation_plan_field(plan_id:, name:, area:, daily_fixed_cost:)
          raise NotImplementedError, "Subclasses must implement upsert_cultivation_plan_field"
        end

        # @raise [StandardError] 見つからない場合（データ不整合）
        def find_plan_crop_id_by_crop_id!(plan_id, crop_id)
          raise NotImplementedError, "Subclasses must implement find_plan_crop_id_by_crop_id!"
        end

        # @param attrs [Hash] CultivationPlan#update! に渡す属性
        def apply_optimization_result(plan_id:, attrs:)
          raise NotImplementedError, "Subclasses must implement apply_optimization_result"
        end
      end
    end
  end
end
