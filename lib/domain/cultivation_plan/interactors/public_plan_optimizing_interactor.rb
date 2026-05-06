# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # GET public_plans/optimizing — 計画の存在・状態はゲートウェイ、HTTP は Presenter
      class PublicPlanOptimizingInteractor
        def initialize(output_port:, plan_id:, gateway:, translator:, logger:)
          @output_port = output_port
          @plan_id = plan_id
          @gateway = gateway
          @translator = translator
          @logger = logger
        end

        def call
          unless @plan_id
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("public_plans.errors.not_found")))
            return
          end

          read_model = @gateway.public_plan_optimizing_read_model(plan_id: @plan_id)
          dto = Assemblers::PublicPlanOptimizingAssembler.call(read_model)
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("public_plans.errors.not_found")))
        end
      end
    end
  end
end
