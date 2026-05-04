# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開プラン保存（セッションの save_data → ユーザー農場・私有計画）。ゲートウェイ経由で PlanSaveSession を実行し、
      # 結果は必ず output_port へ渡す（Application edge #3: コントローラの rescue 主導にしない）。
      class PublicPlanSaveFromSessionInteractor
        def initialize(output_port:, public_plan_save_gateway:, logger:, translator:)
          @output_port = output_port
          @public_plan_save_gateway = public_plan_save_gateway
          @logger = logger
          @translator = translator
        end

        # @param user [User]
        # @param session_data [Hash]
        def call(user:, session_data:)
          result = @public_plan_save_gateway.save_from_session(user: user, session_data: session_data)

          if result.respond_to?(:success?) && result.success?
            @output_port.on_success
            return
          end

          msg = result.respond_to?(:error_message) ? result.error_message : nil
          fallback = @translator.t("public_plans.save.error")
          text = (msg.nil? || msg.to_s.empty?) ? fallback : msg.to_s
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailureDto.new(
              kind: Dtos::PublicPlanSaveFailureDto::KIND_SAVE_FAILED,
              message: text
            )
          )
        rescue Domain::Shared::Exceptions::InvalidTaskScheduleItem => e
          @logger.error("❌ [PublicPlanSaveFromSessionInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailureDto.new(
              kind: Dtos::PublicPlanSaveFailureDto::KIND_UNEXPECTED,
              message: @translator.t("public_plans.save.error")
            )
          )
        rescue StandardError => e
          @logger.error("❌ [PublicPlanSaveFromSessionInteractor] #{e.class}: #{e.message}")
          @logger.error(e.backtrace&.first(30)&.join("\n").to_s)
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailureDto.new(
              kind: Dtos::PublicPlanSaveFailureDto::KIND_UNEXPECTED,
              message: @translator.t("public_plans.save.error")
            )
          )
        end
      end
    end
  end
end
