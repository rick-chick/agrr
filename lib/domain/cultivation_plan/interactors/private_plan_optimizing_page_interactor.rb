# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanOptimizingPageInteractor
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
          dto = @gateway.private_plan_optimizing_page_context(plan_id: @plan_id, user: user)
          @output_port.on_success(dto)
        rescue ::PolicyPermissionDenied, Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue StandardError => e
          @logger.error("[PrivatePlanOptimizingPageInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.restart")))
        end
      end
    end
  end
end
