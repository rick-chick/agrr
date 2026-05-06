# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanCreateInteractor < Domain::PublicPlan::Ports::PublicPlanCreateInputPort
        # @param clock [#today] CompositionRoot で Time.zone を渡す想定（禁止4）。
        # @param optimization_job_chain_gateway [Domain::PublicPlan::Gateways::PublicPlanOptimizationJobChainGateway, nil] 成功時にジョブチェーンをエンキューする場合のみ注入
        def initialize(output_port:, gateway:, cultivation_plan_gateway:, logger:, clock:, optimization_job_chain_gateway: nil)
          raise ArgumentError, "clock must respond to :today" unless clock.respond_to?(:today)

          @output_port = output_port
          @logger = logger
          @gateway = gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @clock = clock
          @optimization_job_chain_gateway = optimization_job_chain_gateway
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

          # 計画を作成（永続化は CultivationPlanGateway 経由。ユースケース編成はここに集約）
          # Old: planning_start_date: Date.current; planning_end_date: Date.current.end_of_year （各キーワードで today を評価）
          planning_start_date = @clock.today
          planning_end_date = Date.new(@clock.today.year, 12, 31)
          result = Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor.new(
            farm: farm,
            total_area: total_area,
            crops: crops,
            user: input_dto.user,
            session_id: input_dto.session_id,
            plan_type: "public",
            planning_start_date: planning_start_date,
            planning_end_date: planning_end_date,
            gateway: @cultivation_plan_gateway,
            logger: @logger
          ).call

          unless result.success? && result.cultivation_plan
            error_message = result.errors&.join(", ") || "Failed to create cultivation plan"
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(error_message))
            return
          end

          cultivation_plan = result.cultivation_plan
          plan_id = cultivation_plan.id

          # 契約に従い plan_id をログ出力
          @logger.info "🌱 [PublicPlanCreateInteractor] Created new CultivationPlan with plan_id: #{plan_id}"

          # 成功レスポンスを返す（ジョブチェーンは表現層の前にエッジ注入ゲートウェイで実行）
          success_dto = Domain::PublicPlan::Dtos::PublicPlanCreateSuccessDto.new(plan_id: plan_id)
          @optimization_job_chain_gateway&.enqueue_after_create!(
            cultivation_plan_id: plan_id,
            caller_label: self.class.name
          )
          @output_port.on_success(success_dto)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn "❌ [PublicPlanCreateInteractor] Validation: #{e.message}"
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
