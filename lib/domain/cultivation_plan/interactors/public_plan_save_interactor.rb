# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 公開計画をユーザーアカウントへ保存する（オーケストレーション本体）。
      class PublicPlanSaveInteractor
        def initialize(
          output_port:,
          txn_gateway:,
          read_gateway:,
          farm_gateway:,
          persistence_port:,
          logger:,
          translator:
        )
          @output_port = output_port
          @txn_gateway = txn_gateway
          @read_gateway = read_gateway
          @farm_gateway = farm_gateway
          @persistence_port = persistence_port
          @logger = logger
          @translator = translator
        end

        # @param input [Dtos::PublicPlanSaveInput]
        def call(input)
          fdto = Dtos::PublicPlanSaveFailure
          unless input.plan_id_present?
            @output_port.on_failure(fdto.new(kind: fdto::KIND_MISSING_PLAN_ID))
            return
          end

          session_data = resolve_session_data(input)
          unless session_data
            @output_port.on_failure(fdto.new(kind: fdto::KIND_PLAN_NOT_FOUND))
            return
          end

          workspace = Dtos::PublicPlanSaveWorkspace.new(
            user_id: input.user_id,
            session_data: session_data
          )

          output = persist_workspace!(workspace)

          if output.success?
            plan_reused = plan_reused?(output.skipped_items)
            @output_port.on_success(
              Dtos::PublicPlanSaveSuccess.new(
                cultivation_plan_id: output.new_cultivation_plan_id,
                plan_reused: plan_reused
              )
            )
            return
          end

          msg = output.error_message
          fallback = @translator.t("public_plans.save.error")
          text = msg.nil? || msg.to_s.empty? ? fallback : msg.to_s
          @output_port.on_failure(
            fdto.new(kind: fdto::KIND_SAVE_FAILED, message: text)
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

        private

        # オーケストレーション: farm → fields → crops → region masters → 既存 plan 判定 → plan copy → blueprint → schedules
        # （永続化詳細は PublicPlanSavePersistencePort / PlanSaveSession + TemplateCopyGateway）
        def persist_workspace!(workspace)
          output = nil
          @txn_gateway.within_transaction do
            output = @persistence_port.execute_save!(workspace: workspace)
          end
          output
        end

        def plan_reused?(skipped_items)
          return false unless skipped_items.is_a?(Hash)

          plan_skips = skipped_items[:plan] || skipped_items["plan"]
          plan_skips.present?
        end

        def resolve_session_data(input)
          return input.session_data if input.session_data

          plan_id = input.plan_id.to_i
          header = @read_gateway.find_header_snapshot(plan_id: plan_id)
          return nil unless header

          reference_farm = @farm_gateway.find_by_id(header.farm_id)
          return nil unless reference_farm

          field_rows = @read_gateway.list_field_rows(plan_id: plan_id)
          Mappers::PublicPlanSaveSessionDataMapper.from_snapshots(
            header: header,
            field_rows: field_rows
          )
        end
      end
    end
  end
end
