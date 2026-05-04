# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # CultivationPlanApi の add_field / remove_field / data / adjust の手続きと失敗種別の正規化。
    class ApiCultivationPlanRestFlow
      def initialize(host_controller)
        @host = host_controller
      end

      def add_field_run(plan_loader:, field_name:, field_area:, daily_fixed_cost:)
        cultivation_plan =
          begin
            plan_loader.load
          rescue ActiveRecord::RecordNotFound
            return { kind: :not_found }
          end

        @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

        field_area_f = field_area&.to_f
        if field_area_f <= 0
          return { kind: :invalid_field_params }
        end

        if cultivation_plan.cultivation_plan_fields.count >= 5
          return { kind: :max_fields_limit }
        end

        plan_field = cultivation_plan.cultivation_plan_fields.create!(
          name: field_name,
          area: field_area_f,
          daily_fixed_cost: daily_fixed_cost&.to_f
        )

        cultivation_plan.update!(total_area: cultivation_plan.cultivation_plan_fields.sum(:area))

        channel_class = cultivation_plan.plan_type == "private" ? PlansOptimizationChannel : OptimizationChannel
        channel_class.broadcast_to(
          cultivation_plan,
          {
            type: "field_added",
            field: {
              id: plan_field.id,
              field_id: plan_field.id,
              name: plan_field.name,
              area: plan_field.area
            },
            total_area: cultivation_plan.total_area
          }
        )

        { kind: :success, plan_field: plan_field, total_area: cultivation_plan.total_area }
      rescue ActiveRecord::RecordInvalid => e
        @host.logger.error "❌ [Add Field] Record invalid: #{e.message}"
        { kind: :record_invalid, message: e.message }
      rescue StandardError => e
        @host.logger.error "❌ [Add Field] Error: #{e.message}"
        { kind: :unexpected, message: e.message }
      end

      def remove_field_run(plan_loader:, field_id_param:)
        cultivation_plan =
          begin
            plan_loader.load
          rescue ActiveRecord::RecordNotFound
            return { kind: :not_found }
          end

        @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

        field_id = field_id_param.to_i
        plan_field = cultivation_plan.cultivation_plan_fields.find_by(id: field_id)

        unless plan_field
          return { kind: :field_not_found }
        end

        if plan_field.field_cultivations.any?
          return { kind: :cannot_remove_with_cultivations }
        end

        if cultivation_plan.cultivation_plan_fields.count <= 1
          return { kind: :cannot_remove_last_field }
        end

        plan_field.destroy!

        cultivation_plan.update!(total_area: cultivation_plan.cultivation_plan_fields.sum(:area))

        channel_class = cultivation_plan.plan_type == "private" ? PlansOptimizationChannel : OptimizationChannel
        channel_class.broadcast_to(
          cultivation_plan,
          {
            type: "field_removed",
            field_id: field_id,
            total_area: cultivation_plan.total_area
          }
        )

        { kind: :success, field_id: field_id, total_area: cultivation_plan.total_area }
      rescue ActiveRecord::RecordNotFound => e
        @host.logger.error "❌ [Remove Field] Not found: #{e.message}"
        { kind: :field_not_found }
      rescue StandardError => e
        @host.logger.error "❌ [Remove Field] Error: #{e.message}"
        { kind: :unexpected, message: e.message }
      end

      def data_run(plan_loader:)
        cultivation_plan =
          begin
            plan_loader.load
          rescue ActiveRecord::RecordNotFound
            return { kind: :not_found }
          end

        @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

        fields_data = cultivation_plan.cultivation_plan_fields.map do |field|
          {
            id: field.id,
            field_id: field.id,
            name: field.display_name,
            area: field.area,
            daily_fixed_cost: field.daily_fixed_cost
          }
        end

        crops_data = cultivation_plan.cultivation_plan_crops.map do |crop|
          {
            id: crop.id,
            name: crop.display_name,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area
          }
        end

        available_crops_data = @host.send(:get_available_crops).map do |crop|
          {
            id: crop.id,
            name: crop.name,
            variety: crop.variety,
            area_per_unit: crop.area_per_unit
          }
        end

        cultivations_data = cultivation_plan.field_cultivations.map do |fc|
          {
            id: fc.id,
            field_id: fc.cultivation_plan_field_id,
            field_name: fc.field_display_name,
            crop_id: fc.cultivation_plan_crop_id,
            crop_name: fc.crop_display_name,
            area: fc.area,
            start_date: fc.start_date,
            completion_date: fc.completion_date,
            cultivation_days: fc.cultivation_days,
            estimated_cost: fc.estimated_cost,
            revenue: fc.optimization_result&.dig("revenue") || 0.0,
            profit: fc.optimization_result&.dig("profit") || 0.0,
            status: fc.status
          }
        end

        body = {
          success: true,
          data: {
            id: cultivation_plan.id,
            plan_year: cultivation_plan.plan_year,
            plan_name: cultivation_plan.plan_name,
            plan_type: cultivation_plan.plan_type,
            status: cultivation_plan.status,
            total_area: cultivation_plan.total_area,
            planning_start_date: cultivation_plan.calculated_planning_start_date,
            planning_end_date: cultivation_plan.prediction_target_end_date,
            fields: fields_data,
            crops: crops_data,
            available_crops: available_crops_data,
            cultivations: cultivations_data
          },
          total_profit: cultivation_plan.total_profit,
          total_revenue: cultivation_plan.total_revenue,
          total_cost: cultivation_plan.total_cost
        }

        { kind: :success, body: body }
      rescue StandardError => e
        @host.logger.error "❌ [Data] Error: #{e.message}"
        { kind: :unexpected, message: e.message }
      end

      def adjust_run(plan_loader:, moves_raw:)
        cultivation_plan =
          begin
            plan_loader.load
          rescue ActiveRecord::RecordNotFound
            return { kind: :not_found }
          end

        @host.instance_variable_set(:@cultivation_plan, cultivation_plan)

        validation = @host.send(:validate_crops_have_growth_stages_result, cultivation_plan)
        if validation
          return validation
        end

        moves = normalize_adjust_moves(moves_raw)
        @host.logger.info "🔧 [Adjust] Processed moves with type conversion: #{moves.inspect}"

        result = @host.adjust_with_db_weather(cultivation_plan, moves)
        { kind: :adjust_result, adjust_hash: result }
      rescue StandardError => e
        @host.logger.error "❌ [Adjust] Error: #{e.message}"
        { kind: :unexpected, message: e.message }
      end

      private

      def normalize_adjust_moves(moves_raw)
        Rails.logger.info "📥 [Adjust] Received moves: #{moves_raw.inspect}"
        Rails.logger.info "📥 [Adjust] Moves class: #{moves_raw.class}"

        moves = if moves_raw.is_a?(Array)
          moves_raw.map do |move|
            case move
            when ActionController::Parameters
              move.permit!.to_h.symbolize_keys
            when Hash
              move.symbolize_keys
            when String
              begin
                JSON.parse(move).symbolize_keys
              rescue JSON::ParserError
                Rails.logger.error "❌ [Adjust] Failed to parse move: #{move}"
                nil
              end
            else
              nil
            end
          end.compact
        else
          []
        end

        moves.map do |move|
          if move[:allocation_id].present?
            move[:allocation_id] = move[:allocation_id].to_i
          end
          if move[:to_field_id].present?
            move[:to_field_id] = move[:to_field_id].to_s
          end
          move
        end
      end
    end
  end
end
