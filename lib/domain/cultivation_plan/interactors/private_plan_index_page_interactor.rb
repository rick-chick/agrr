# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class PrivatePlanIndexPageInteractor
        def initialize(output_port:, user_id:, gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          dto = @gateway.private_plan_index_page(user: user)
          @output_port.on_success(dto)
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue ActiveRecord::StatementInvalid, ActiveRecord::ConnectionNotEstablished => e
          @logger.error("[PrivatePlanIndexPageInteractor] #{e.class}: #{e.message}")
          raise
        rescue StandardError => e
          @logger.error("[PrivatePlanIndexPageInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("plans.errors.restart")))
        end
      end
    end
  end
end
