# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanOptimizingInteractor
        def initialize(output_port:, user_id:, plan_id:, gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @plan_id = plan_id
          @gateway = gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          read_model = @gateway.private_plan_optimizing_read_model(plan_id: @plan_id, user: user)
          dto = Assemblers::PrivatePlanOptimizingAssembler.call(read_model)
          @output_port.on_success(dto)
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue StandardError => e
          @logger.error("[PrivatePlanOptimizingInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.restart")))
        end
      end
    end
  end
end
