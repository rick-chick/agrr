# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class CultivationPlanCreateInteractor < Domain::CultivationPlan::Ports::CultivationPlanCreateInputPort
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(input_dto)
          # 農場を取得
          farm = @gateway.find_farm(input_dto.farm_id, input_dto.user)
          unless farm
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Farm not found"))
            return
          end

          # 作物を取得
          crops = @gateway.find_crops(input_dto.crop_ids, input_dto.user)
          if crops.empty? && input_dto.crop_ids.present?
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("No valid crops found"))
            return
          end

          # 既存の計画をチェック
          existing_plan = @gateway.find_existing(farm, input_dto.user)
          if existing_plan
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Plan already exists for this farm"))
            return
          end

          # 計画を作成
          result = @gateway.create(
            Domain::CultivationPlan::Dtos::CultivationPlanCreateGatewayDto.new(
              farm: farm,
              crops: crops,
              user: input_dto.user,
              plan_name: input_dto.plan_name,
              total_area: farm.fields.sum(:area)
            )
          )

          if result.success? && result.cultivation_plan
            success_dto = Domain::CultivationPlan::Dtos::CultivationPlanCreateSuccessDto.new(
              id: result.cultivation_plan.id,
              name: result.cultivation_plan.display_name,
              status: result.cultivation_plan.status
            )
            @output_port.on_success(success_dto)
          else
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new("Failed to create cultivation plan"))
          end
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end