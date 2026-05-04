# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # add_crop API: アダプタ層の実行結果を出力ポートへ写す（コントローラでは rescue 主導にしない）。
      class ApiAddCropInteractor
        def initialize(output:, flow: nil)
          @output = output
          @flow = flow
        end

        # @param host [ApplicationController] CultivationPlanApi を include したコントローラ
        # @param load_plan [Proc] find_api_cultivation_plan 相当（RecordNotFound の可能性あり）
        def call(host:, load_plan:, crop_id:, field_id:, display_range:)
          flow = @flow || Adapters::CultivationPlan::ApiAddCropFlow.new(host)
          result = flow.full_run(
            load_plan: load_plan,
            crop_id: crop_id,
            field_id: field_id,
            display_range: display_range
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
