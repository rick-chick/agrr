# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanOptimizationRedirectInteractor
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
          user = begin
            @user_lookup.find(@user_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            @logger.warn("[PrivatePlanOptimizationRedirectInteractor] user_record_not_found user_id=#{@user_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.session_invalid")))
            return
          end

          dto = @gateway.private_plan_optimization_redirect_snapshot(user: user, plan_id: @plan_id)
          @output_port.on_success(dto)
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          log_interactor_error(e)
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivatePlanOptimizationRedirectInteractor] record_not_found: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivatePlanOptimizationRedirectInteractor] record_invalid: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end

        private

        def log_interactor_error(error)
          bt = error.backtrace&.first(20)&.join("\n").to_s
          @logger.error(
            "[PrivatePlanOptimizationRedirectInteractor] #{error.class}: #{error.message}\n/backtrace:\n#{bt}"
          )
        end
      end
    end
  end
end
