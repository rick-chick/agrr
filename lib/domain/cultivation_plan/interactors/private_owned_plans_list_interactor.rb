# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 認証ユーザーに紐づく私有計画の一覧（軽量 read）。
      class PrivateOwnedPlansListInteractor
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
          rows = @gateway.private_plan_index_plan_rows(user: user)
          @output_port.on_success(rows)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @logger.warn("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("plans.errors.session_invalid")))
        rescue NoMethodError, NameError, ArgumentError, SyntaxError
          raise
        rescue Domain::Shared::Exceptions::PersistenceFailed => e
          @logger.error("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          raise
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn("[PrivateOwnedPlansListInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
