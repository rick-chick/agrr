# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      class ManualPlanAdjustInteractor
        def initialize(output:, adjust_plan_growth_read_gateway:, adjust_with_db_weather:, logger:)
          @output = output
          @adjust_plan_growth_read_gateway = adjust_plan_growth_read_gateway
          @adjust_with_db_weather = adjust_with_db_weather
          @logger = logger
        end

        # @param moves [Array<Hash>] エッジで AdjustMovesFromRequest.normalize 済み
        def call(auth:, plan_id:, moves:)
          read = @adjust_plan_growth_read_gateway.load(auth: auth, plan_id: plan_id)

          case read[:kind]
          when :not_found
            @output.on_not_found
            return
          when :unexpected, :record_invalid
            @output.on_unexpected(message: read.fetch(:message))
            return
          when :success
            read.fetch(:crop_rows).each do |row|
              if row.growth_stage_count.zero?
                @output.on_crop_missing_growth_stages(crop_name: row.crop_name)
                return
              end
            end
          else
            @output.on_unexpected(message: "Unknown adjust growth read: #{read[:kind].inspect}")
            return
          end

          adjust_hash = @adjust_with_db_weather.call(plan_id: plan_id, moves: moves)
          @output.on_adjust(result: adjust_hash)
        rescue StandardError => e
          @logger.error "❌ [Adjust] Error: #{e.message}"
          @output.on_unexpected(message: e.message)
        end
      end
    end
  end
end
