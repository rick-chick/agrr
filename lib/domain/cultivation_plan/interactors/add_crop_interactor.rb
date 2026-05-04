# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # add_crop REST: Gateway 協調結果を出力ポートへ写す。
      class AddCropInteractor
        def initialize(output:, add_crop_coordinator_gateway:)
          @output = output
          @add_crop_coordinator_gateway = add_crop_coordinator_gateway
        end

        # @param crop_resolver [#crop_for_add_crop] エッジで実装（Concern の作物解決）。
        def call(auth:, plan_id:, crop_id:, field_id:, display_range:, crop_resolver:)
          result = @add_crop_coordinator_gateway.run(
            auth: auth,
            plan_id: plan_id,
            crop_id: crop_id,
            field_id: field_id,
            display_range: display_range,
            crop_resolver: crop_resolver
          )

          case result[:kind]
          when :success
            @output.on_success(
              plan_crop_id: result[:plan_crop_id],
              plan_crop_display_name: result[:plan_crop_display_name]
            )
          when :not_found
            @output.on_not_found
          when :crop_not_found
            @output.on_crop_not_found
          when :prediction_incomplete
            @output.on_prediction_incomplete(technical_details: result.fetch(:technical_details))
          when :no_candidates
            @output.on_no_candidates
          when :adjust_failed
            @output.on_adjust_failed(adjust_payload: result.fetch(:adjust_payload))
          when :record_invalid
            @output.on_record_invalid(message: result.fetch(:message))
          when :unexpected
            @output.on_unexpected(message: result.fetch(:message))
          else
            @output.on_unexpected(message: "Unknown add_crop result: #{result[:kind].inspect}")
          end
        end
      end
    end
  end
end
