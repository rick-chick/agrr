# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanShowInteractor
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
            @logger.warn("[PrivatePlanShowInteractor] user_record_not_found user_id=#{@user_id.inspect}")
            @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.session_invalid")))
            return
          end

          detail = @gateway.find_private_cultivation_plan_detail(user: user, plan_id: @plan_id)
          dto = Domain::CultivationPlan::Assemblers::PrivatePlanShowAssembler.call(detail)
          @output_port.on_success(dto)
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        # PersistenceFailed: 永続層の失敗はユーザー向けフラッシュではなくログのうえ再送出し、
        # Rails の例外処理（通常は 500）に任せる。on_failure には回さない。
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          log_interactor_error(e)
          raise
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivatePlanShowInteractor] record_not_found: #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.not_found")))
        rescue StandardError => e
          log_interactor_error(e)
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.restart")))
        end

        private

        def log_interactor_error(error)
          bt = error.backtrace&.first(20)&.join("\n").to_s
          @logger.error(
            "[PrivatePlanShowInteractor] #{error.class}: #{error.message}\n/backtrace:\n#{bt}"
          )
        end
      end
    end
  end
end
