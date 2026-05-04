# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      class CultivationPlanGateway
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

        # @return [Float]
        def total_field_area_for_farm(farm_id, user)
          raise NotImplementedError, "Subclasses must implement total_field_area_for_farm"
        end

        def destroy(plan_id, user)
          raise NotImplementedError, "Subclasses must implement destroy"
        end

        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def find_by_id(plan_id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end

        # phase 更新 proxy (phase_fetching_weather! など)
        # @return [Boolean]
        def update_phase(plan_id, phase_name, *args)
          raise NotImplementedError, "Subclasses must implement update_phase"
        end

        # @return [Domain::CultivationPlan::Dtos::TaskScheduleGenerationContext]
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
        # @param logger [#info] DI 必須。当メソッド（年度私有コピー）は #info のみ使用。
        #   推奨は {Domain::Logger::Gateways::LoggerGateway} のサブクラス（ダックタイプでも可）。
        # @return [Domain::CultivationPlan::Entities::CultivationPlanEntity]
        def copy_private_plan_for_year(source_cultivation_plan_id:, new_year:, user:, session_id: nil, logger:)
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

        # @return [Array<Domain::CultivationPlan::Dtos::CultivationPlanCropWithAgrrDto>]
        def cultivation_plan_crops_with_crop(plan_id)
          raise NotImplementedError, "Subclasses must implement cultivation_plan_crops_with_crop"
        end

        def clear_field_cultivations(plan_id)
          raise NotImplementedError, "Subclasses must implement clear_field_cultivations"
        end

        # @param attrs [Hash] FieldCultivation#create! に渡す属性（シンボルキー可）
        # @return [Domain::CultivationPlan::Entities::FieldCultivationEntity]
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

        # CultivationPlanOptimizeInteractor 用スナップショット（AR をインターラクタに渡さない）
        def optimization_plan_snapshot(plan_id)
          raise NotImplementedError, "Subclasses must implement optimization_plan_snapshot"
        end

        # プライベート計画「最適化進捗」HTML 用（認可つき）。読み取りスナップショットのみ（PageDto は Assembler 側）。
        # @return [Domain::CultivationPlan::Dtos::PrivatePlanOptimizingReadModel]
        def private_plan_optimizing_read_model(plan_id:, user:)
          raise NotImplementedError, "Subclasses must implement private_plan_optimizing_read_model"
        end

        # プライベート計画一覧（HTML index）の行データのみ
        # @return [Array<Domain::CultivationPlan::Dtos::PrivatePlanIndexPlanRowDto>]
        def private_plan_index_plan_rows(user:)
          raise NotImplementedError, "Subclasses must implement private_plan_index_plan_rows"
        end

        # プライベート計画の読み取り専用スナップショット（認可つき）。View やガント埋め込み形は知らない。
        # @return [Domain::CultivationPlan::Dtos::PrivateCultivationPlanDetailDto]
        def find_private_cultivation_plan_detail(user:, plan_id:)
          raise NotImplementedError, "Subclasses must implement find_private_cultivation_plan_detail"
        end
      end
    end
  end
end
