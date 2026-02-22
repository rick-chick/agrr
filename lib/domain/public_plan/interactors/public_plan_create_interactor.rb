# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanCreateInteractor < Domain::PublicPlan::Ports::PublicPlanCreateInputPort
        def initialize(output_port:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @logger = logger
        end

        def call(input_dto)
          # 農場を取得
          farm = @gateway.find_farm(input_dto.farm_id)
          unless farm
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Farm not found"))
            return
          end

          # 農場サイズを取得
          farm_size = @gateway.find_farm_size(input_dto.farm_size_id)
          unless farm_size
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Invalid farm size"))
            return
          end

          total_area = farm_size[:area_sqm]
          unless total_area&.positive?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Invalid total area"))
            return
          end

          # 作物を取得
          crops = @gateway.find_crops(input_dto.crop_ids)
          if crops.empty?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("No crops selected"))
            return
          end

          # 計画を作成（常に新しい CultivationPlan を作成）
          gateway_dto = Domain::PublicPlan::Dtos::PublicPlanCreateGatewayDto.new(
            farm: farm,
            total_area: total_area,
            crops: crops,
            user: input_dto.user,
            session_id: input_dto.session_id,
            planning_start_date: Date.current,
            planning_end_date: Date.current.end_of_year
          )

          result = @gateway.create(gateway_dto)

          unless result.success? && result.cultivation_plan
            error_message = result.errors&.join(', ') || "Failed to create cultivation plan"
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(error_message))
            return
          end

          cultivation_plan = result.cultivation_plan
          plan_id = cultivation_plan.id

          # 契約に従い plan_id をログ出力
          @logger.info "🌱 [PublicPlanCreateInteractor] Created new CultivationPlan with plan_id: #{plan_id}"

          # 成功レスポンスを返す
          success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto.new(plan_id: plan_id)
          @output_port.on_success(success_dto)
        rescue StandardError => e
          @logger.error "❌ [PublicPlanCreateInteractor] Unexpected error: #{e.class} - #{e.message}"
          @logger.error e.backtrace.join("\n")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
