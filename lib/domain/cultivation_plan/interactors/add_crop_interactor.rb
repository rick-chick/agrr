# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # add_crop REST: 圃場作物追加と adjust までをオーケストレーションする。
      class AddCropInteractor
        WEATHER_PREDICTION_EXCEPTIONS = [
          Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
          Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError
        ].freeze

        # @param plan_allocation_adjust [Domain::CultivationPlan::Ports::PlanAllocationAdjustInputPort]
        # @param add_crop_crop_resolve [Domain::CultivationPlan::Ports::AddCropCropResolveInputPort]
        # @param add_crop_adjust_result_sink [#add_crop_adjust_result] adjust の output_port（同一リクエスト用 collector）
        def initialize(
          output:,
          logger:,
          plan_allocation_adjust:,
          add_crop_crop_resolve:,
          add_crop_adjust_result_sink:,
          plan_gateway:,
          plan_crop_gateway:,
          find_best_candidate:
        )
          @output = output
          @logger = logger
          @plan_allocation_adjust = plan_allocation_adjust
          @add_crop_crop_resolve = add_crop_crop_resolve
          @add_crop_adjust_result_sink = add_crop_adjust_result_sink
          @plan_gateway = plan_gateway
          @plan_crop_gateway = plan_crop_gateway
          @find_best_candidate = find_best_candidate
        end

        # @param ui_filter_context [Hash] 候補探索ログ用（空可）
        def call(auth:, plan_id:, crop_id:, field_id:, display_range:, ui_filter_context: {})
          plan_crop_id = nil
          user_id = auth.private? ? auth.user_id : nil

          plan = @plan_gateway.find_by_id(plan_id)
          if RestPlanAccess.access_denied?(plan: plan, auth: auth)
            return @output.on_not_found
          end

          crop_entity = @add_crop_crop_resolve.call(auth: auth, crop_id: crop_id)
          unless crop_entity
            @output.on_crop_not_found
            return
          end

          plan_crop_snapshot = @plan_crop_gateway.create(
            plan_id: plan_id,
            crop_entity: crop_entity,
            user_id: user_id
          )
          plan_crop_id = plan_crop_snapshot.id
          plan_crop_display_name = plan_crop_snapshot.display_name

          best = @find_best_candidate.call(
            auth: auth,
            plan_id: plan_id,
            crop: crop_entity,
            field_id: field_id,
            display_range: display_range,
            ui_filter_context: ui_filter_context
          )

          unless best
            rollback_plan_crop(plan_crop_id)
            @output.on_no_candidates
            return
          end

          moves = [
            {
              allocation_id: nil,
              action: "add",
              crop_id: crop_entity.id.to_s,
              to_field_id: best[:field_id],
              to_start_date: best[:start_date],
              to_area: crop_entity.area_per_unit,
              variety: crop_entity.variety
            }
          ]

          @plan_allocation_adjust.call(
            Dtos::PlanAllocationAdjustInput.new(plan_id: plan_id, moves: moves)
          )
          adjust_result = @add_crop_adjust_result_sink.add_crop_adjust_result

          if adjust_result.success?
            @output.on_success(
              plan_crop_id: plan_crop_id,
              plan_crop_display_name: plan_crop_display_name
            )
          else
            @output.on_adjust_failed(adjust_payload: adjust_result_to_legacy_hash(adjust_result))
          end
        rescue Domain::Shared::Exceptions::RecordNotFound
          rollback_plan_crop(plan_crop_id) if plan_crop_id
          @output.on_not_found
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error "❌ [Add Crop] Record invalid: #{e.message}"
          rollback_plan_crop(plan_crop_id) if plan_crop_id
          @output.on_record_invalid(message: e.message)
        rescue *WEATHER_PREDICTION_EXCEPTIONS => e
          @logger.warn "⚠️ [Add Crop] Prediction data incomplete: #{e.message}"
          rollback_plan_crop(plan_crop_id) if plan_crop_id
          @output.on_prediction_incomplete(technical_details: e.message)
        rescue StandardError => e
          @logger.error "❌ [Add Crop] Error: #{e.message}"
          @logger.error e.backtrace.join("\n") if e.backtrace
          rollback_plan_crop(plan_crop_id) if plan_crop_id
          @output.on_unexpected(message: e.message)
        end

        private

        def rollback_plan_crop(plan_crop_id)
          @plan_crop_gateway.delete(id: plan_crop_id)
        rescue Domain::Shared::Exceptions::RecordNotFound
          nil
        end

        def adjust_result_to_legacy_hash(result)
          {
            success: result.success?,
            message: result.message,
            status: result.http_status
          }.compact
        end
      end
    end
  end
end
