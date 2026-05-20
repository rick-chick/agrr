# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 認証ユーザーに属する単一私有計画のサマリ（id / name / status）。
      class PrivateOwnedPlanDetailInteractor
        def initialize(output_port:, user_id:, gateway:, translator:, logger:, user_lookup:)
          @output_port = output_port
          @user_id = user_id
          @gateway = gateway
          @translator = translator
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(plan_id:)
          user = @user_lookup.find(@user_id)
          detail = @gateway.find_private_cultivation_plan_detail(user: user, plan_id: plan_id.to_i)
          @output_port.on_success(detail)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          @output_port.on_not_found
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          @logger.error("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          raise
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivateOwnedPlanDetailInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
