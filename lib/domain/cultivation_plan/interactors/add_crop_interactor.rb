# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # add_crop REST: 狭い Gateway を組み合わせ、出力ポートへ写す。
      class AddCropInteractor
        def initialize(
          output:,
          logger:,
          optimization_host:,
          optimize_attach_gateway:,
          plan_crop_insert_gateway:,
          best_candidate_gateway:,
          adjust_invoke_gateway:,
          plan_crop_delete_gateway:
        )
          @output = output
          @logger = logger
          @optimization_host = optimization_host
          @optimize_attach_gateway = optimize_attach_gateway
          @plan_crop_insert_gateway = plan_crop_insert_gateway
          @best_candidate_gateway = best_candidate_gateway
          @adjust_invoke_gateway = adjust_invoke_gateway
          @plan_crop_delete_gateway = plan_crop_delete_gateway
        end

        # @param crop_resolver [#crop_for_add_crop] エッジで実装（Concern の作物解決）。
        def call(auth:, plan_id:, crop_id:, field_id:, display_range:, crop_resolver:)
          attach1 = @optimize_attach_gateway.attach_plan!(
            auth: auth,
            plan_id: plan_id,
            optimization_host: @optimization_host
          )
          unless attach1[:kind] == :success
            dispatch_optimize_attach_failure(attach1)
            return
          end

          crop_entity = crop_resolver.crop_for_add_crop(crop_id)
          unless crop_entity
            @output.on_crop_not_found
            return
          end

          insert = @plan_crop_insert_gateway.create_plan_crop!(
            auth: auth,
            plan_id: plan_id,
            crop_entity: crop_entity
          )

          case insert[:kind]
          when :not_found
            @output.on_not_found
            return
          when :record_invalid
            @output.on_record_invalid(message: insert.fetch(:message))
            return
          when :unexpected
            @output.on_unexpected(message: insert.fetch(:message))
            return
          when :success
            plan_crop_id = insert.fetch(:plan_crop_id)
            plan_crop_display_name = insert.fetch(:plan_crop_display_name)
          else
            @output.on_unexpected(message: "Unknown add_crop insert: #{insert[:kind].inspect}")
            return
          end

          attach2 = @optimize_attach_gateway.attach_plan!(
            auth: auth,
            plan_id: plan_id,
            optimization_host: @optimization_host
          )
          unless attach2[:kind] == :success
            @plan_crop_delete_gateway.destroy_plan_crop!(plan_crop_id: plan_crop_id)
            dispatch_optimize_attach_failure(attach2)
            return
          end

          candidate = @best_candidate_gateway.find_best(
            auth: auth,
            plan_id: plan_id,
            crop_id: crop_entity.id,
            field_id: field_id,
            display_range: display_range,
            optimization_host: @optimization_host
          )

          unless candidate[:kind] == :found
            dispatch_candidate_failure(candidate, plan_crop_id: plan_crop_id)
            return
          end

          moves = [
            {
              allocation_id: nil,
              action: "add",
              crop_id: crop_entity.id.to_s,
              to_field_id: candidate[:field_id],
              to_start_date: candidate[:start_date],
              to_area: crop_entity.area_per_unit,
              variety: crop_entity.variety
            }
          ]

          result = @adjust_invoke_gateway.adjust_with_moves!(
            optimization_host: @optimization_host,
            plan_id: plan_id,
            moves: moves
          )

          if result[:success] || result["success"]
            @output.on_success(
              plan_crop_id: plan_crop_id,
              plan_crop_display_name: plan_crop_display_name
            )
          else
            @output.on_adjust_failed(adjust_payload: result)
          end
        rescue StandardError => e
          @logger.error "❌ [Add Crop] Error: #{e.message}"
          @logger.error e.backtrace.join("\n") if e.backtrace
          @output.on_unexpected(message: e.message)
        end

        private

        def dispatch_optimize_attach_failure(result)
          case result[:kind]
          when :not_found
            @output.on_not_found
          when :record_invalid
            @output.on_record_invalid(message: result.fetch(:message))
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown add_crop attach: #{result[:kind].inspect}")
          end
        end

        def dispatch_candidate_failure(result, plan_crop_id:)
          @plan_crop_delete_gateway.destroy_plan_crop!(plan_crop_id: plan_crop_id)

          case result[:kind]
          when :prediction_incomplete
            @output.on_prediction_incomplete(technical_details: result.fetch(:technical_details))
          when :no_candidates
            @output.on_no_candidates
          when :not_found
            @output.on_not_found
          when :record_invalid
            @output.on_record_invalid(message: result.fetch(:message))
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown add_crop candidate: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
