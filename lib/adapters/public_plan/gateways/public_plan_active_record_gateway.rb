# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Gateways
      class PublicPlanActiveRecordGateway < Domain::PublicPlan::Gateways::PublicPlanGateway
        def initialize(logger:)
          @logger = logger
        end

        def find_farm(farm_id)
          ::Farm.find_by(id: farm_id)
        end

        def find_farm_size(farm_size_id)
          farm_sizes = [
            { id: 'home_garden', area_sqm: 30 },
            { id: 'community_garden', area_sqm: 50 },
            { id: 'rental_farm', area_sqm: 300 }
          ]
          
          farm_sizes.find do |size|
            size[:id].to_s == farm_size_id.to_s || size[:area_sqm] == farm_size_id.to_i
          end
        end

        def find_crops(crop_ids)
          ::Crop.where(id: crop_ids).to_a
        end

        def create(create_dto)
          # CultivationPlanCreatorを使って計画を作成（常に新しい計画を作成）
          creator = CultivationPlanCreator.new(
            farm: create_dto.farm,
            total_area: create_dto.total_area,
            crops: create_dto.crops,
            user: create_dto.user,
            session_id: create_dto.session_id,
            plan_type: 'public',
            planning_start_date: create_dto.planning_start_date,
            planning_end_date: create_dto.planning_end_date
          )

          result = creator.call

          # 成功時に plan_id をログ出力
          if result.success? && result.cultivation_plan
            plan_id = result.cultivation_plan.id
            @logger.info "🌱 [PublicPlanActiveRecordGateway] Created new CultivationPlan with plan_id: #{plan_id}"
          else
            # 失敗時のエラーログ出力
            error_message = result.errors&.join(', ') || "Failed to create cultivation plan"
            @logger.error "❌ [PublicPlanActiveRecordGateway] CultivationPlan creation failed: #{error_message}"
            raise StandardError, error_message
          end

          result
        rescue StandardError => e
          # 例外を適切に処理し、再発生させる
          @logger.error "❌ [PublicPlanActiveRecordGateway] Unexpected error during plan creation: #{e.class} - #{e.message}"
          @logger.error e.backtrace.join("\n")
          raise
        end
      end
    end
  end
end
