# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      # 公開プラン HTML ウィザード step3: セッション農場 + 農場サイズを検証し、@farm を Presenter 経由でセットする。
      class PublicPlanWizardPrepareCropStepInteractor
        ALLOWED_FARM_SIZE_IDS = %w[home_garden community_garden rental_farm].freeze

        def initialize(public_plan_gateway:, output_port:)
          @public_plan_gateway = public_plan_gateway
          @output_port = output_port
        end

        def call(farm_id:, farm_size_id:)
          if farm_id.blank?
            @output_port.on_missing_session
            return
          end

          farm = @public_plan_gateway.find_by_farm_id(farm_id)
          unless farm
            @output_port.on_missing_farm
            return
          end

          farm_size = @public_plan_gateway.find_by_farm_size_id(farm_size_id)
          unless farm_size && ALLOWED_FARM_SIZE_IDS.include?(farm_size[:id].to_s)
            @output_port.on_invalid_farm_size(farm_id: farm.id)
            return
          end

          @output_port.on_success(farm: farm)
        end
      end
    end
  end
end
