# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanIndexInteractor
        def initialize(output_port:, user_id:, gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = begin
            @user_lookup.find(@user_id)
          rescue Domain::Shared::Exceptions::RecordNotFound
            @logger.warn("[PrivatePlanIndexInteractor] user_record_not_found user_id=#{@user_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("plans.errors.session_invalid")))
            return
          end

          plan_rows = @gateway.private_plan_index_plan_rows(user: user)
          dto = Assemblers::PrivatePlanIndexAssembler.call(plan_rows: plan_rows)
          @output_port.on_success(dto)
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          log_interactor_error(e)
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivatePlanIndexInteractor] record_not_found: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("plans.errors.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivatePlanIndexInteractor] record_invalid: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end

        private

        def log_interactor_error(error)
          bt = error.backtrace&.first(20)&.join("\n").to_s
          @logger.error(
            "[PrivatePlanIndexInteractor] #{error.class}: #{error.message}\n/backtrace:\n#{bt}"
          )
        end
      end
    end
  end
end
