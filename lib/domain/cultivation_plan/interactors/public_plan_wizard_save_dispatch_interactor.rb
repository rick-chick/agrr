# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン HTML `save_plan`: 計画の存在・保存ペイロードをゲートウェイで解決し、
      # 匿名利用者はセッション退避＋ログインへ、認証済みは `PublicPlanSaveFromSessionInteractor` へ委譲する。
      class PublicPlanWizardSaveDispatchInteractor
        def initialize(output_port:, cultivation_plan_gateway:, public_plan_save_gateway:, logger:, translator:)
          @output_port = output_port
          @cultivation_plan_gateway = cultivation_plan_gateway
          @public_plan_save_gateway = public_plan_save_gateway
          @logger = logger
          @translator = translator
        end

        # @param plan_id [Integer, nil]
        # @param farm_id [Object]
        # @param crop_ids [Object]
        # @param user [User, nil]
        def call(plan_id:, farm_id:, crop_ids:, user:)
          unless plan_id.is_a?(Integer) && plan_id.positive?
            @output_port.on_plan_not_found
            return
          end

          unless @cultivation_plan_gateway.public_plan_wizard_plan_exists?(plan_id: plan_id)
            @output_port.on_plan_not_found
            return
          end

          payload = @cultivation_plan_gateway.public_plan_wizard_save_session_payload(
            plan_id: plan_id,
            farm_id: farm_id,
            crop_ids: crop_ids
          )
          unless payload
            @logger.warn("❌ [PublicPlanWizardSaveDispatchInteractor] Plan not found for payload: #{plan_id}")
            @output_port.on_save_payload_unavailable(plan_id: plan_id)
            return
          end

          if anonymous_visitor?(user)
            @output_port.on_requires_login(session_data: payload)
            return
          end

          PublicPlanSaveFromSessionInteractor.new(
            output_port: @output_port,
            public_plan_save_gateway: @public_plan_save_gateway,
            logger: @logger,
            translator: @translator
          ).call(user: user, session_data: payload)
        end

        private

        def anonymous_visitor?(user)
          user.nil? || (user.respond_to?(:anonymous?) && user.anonymous?)
        end
      end
    end
  end
end
