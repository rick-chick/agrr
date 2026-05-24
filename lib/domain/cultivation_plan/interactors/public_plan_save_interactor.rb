# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 既存の公開計画 id から保存用ペイロードを組み立て、edge 注入 runner で保存する。
      class PublicPlanSaveInteractor
        def initialize(
          output_port:,
          cultivation_plan_gateway:,
          save_from_session_runner:,
          logger:,
          translator:
        )
          @output_port = output_port
          @cultivation_plan_gateway = cultivation_plan_gateway
          @save_from_session_runner = save_from_session_runner
          @logger = logger
          @translator = translator
        end

        def call(plan_id:, user:)
          fdto = Dtos::PublicPlanSaveFailure
          if plan_id.blank?
            @output_port.on_failure(fdto.new(kind: fdto::KIND_MISSING_PLAN_ID))
            return
          end

          save_data = @cultivation_plan_gateway.session_data_for_public_plan_save_from_plan_id(
            plan_id: plan_id.to_i
          )
          unless save_data
            @output_port.on_failure(fdto.new(kind: fdto::KIND_PLAN_NOT_FOUND))
            return
          end

          result = @save_from_session_runner.call(user: user, session_data: save_data)
          if result.respond_to?(:success?) && result.success?
            @output_port.on_success
            return
          end

          msg = result.respond_to?(:error_message) ? result.error_message : nil
          fallback = @translator.t("public_plans.save.error")
          text = (msg.nil? || msg.to_s.empty?) ? fallback : msg.to_s
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailure.new(
              kind: Dtos::PublicPlanSaveFailure::KIND_SAVE_FAILED,
              message: text
            )
          )
        rescue Domain::Shared::Exceptions::InvalidTaskScheduleItem => e
          @logger.error("❌ [PublicPlanSaveInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailure.new(
              kind: Dtos::PublicPlanSaveFailure::KIND_UNEXPECTED,
              message: @translator.t("public_plans.save.error")
            )
          )
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("❌ [PublicPlanSaveInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(
            Dtos::PublicPlanSaveFailure.new(
              kind: Dtos::PublicPlanSaveFailure::KIND_SAVE_FAILED,
              message: e.message
            )
          )
        end
      end
    end
  end
end
