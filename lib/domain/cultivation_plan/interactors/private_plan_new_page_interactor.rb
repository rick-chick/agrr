# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanNewPageInteractor
        def initialize(output_port:, user_id:, farm_gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @farm_gateway = farm_gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = begin
            @user_lookup.find(@user_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            @logger.warn("[PrivatePlanNewPageInteractor] user_record_not_found user_id=#{@user_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.session_invalid")))
            return
          end

          farm_choices = @farm_gateway.private_plan_new_farm_choices(user: user)
          dto = Assemblers::PrivatePlanNewPageAssembler.call(
            farm_choices: farm_choices,
            default_plan_name: @translator.t("plans.default_plan_name")
          )
          @output_port.on_success(dto)
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          log_interactor_error(e)
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivatePlanNewPageInteractor] record_not_found: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue StandardError => e
          log_interactor_error(e)
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.restart")))
        end

        private

        def log_interactor_error(error)
          bt = error.backtrace&.first(20)&.join("\n").to_s
          @logger.error(
            "[PrivatePlanNewPageInteractor] #{error.class}: #{error.message}\n/backtrace:\n#{bt}"
          )
        end
      end
    end
  end
end
