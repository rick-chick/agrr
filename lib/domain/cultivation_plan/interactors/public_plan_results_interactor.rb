# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # GET public_plans/results — 計画の存在・完了状態はゲートウェイ、HTTP は Presenter
      class PublicPlanResultsInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(plan_id:)
          unless plan_id.is_a?(Integer) && plan_id.positive?
            @output_port.on_not_found
            return
          end

          read_model = @gateway.public_plan_results_snapshot(plan_id: plan_id)
          if read_model.nil?
            @output_port.on_not_found
            return
          end

          unless read_model.status_completed
            @output_port.redirect_to_optimizing
            return
          end

          @output_port.on_success(read_model)
        end
      end
    end
  end
end
