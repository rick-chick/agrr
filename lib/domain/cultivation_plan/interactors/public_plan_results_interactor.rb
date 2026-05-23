# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # GET public_plans/results — 計画の存在・完了状態はゲートウェイ、HTTP は Presenter
      class PublicPlanResultsInteractor
        def initialize(output_port:, gateway:, clock:)
          @output_port = output_port
          @gateway = gateway
          @clock = clock
        end

        def call(plan_id:)
          unless plan_id.is_a?(Integer) && plan_id.positive?
            @output_port.on_not_found
            return
          end

          read_model = @gateway.public_plan_results_snapshot(plan_id: plan_id)
          if read_model.nil?
            @output_port.on_not_found
            return
          end

          unless read_model.status_completed
            @output_port.redirect_to_optimizing
            return
          end

          @output_port.on_success(ensure_planning_start_date_for_gantt(read_model))
        end

        private

        def ensure_planning_start_date_for_gantt(read_model)
          return read_model if read_model.planning_start_date

          Domain::CultivationPlan::Dtos::PublicPlanResultsSnapshot.new(
            plan_id: read_model.plan_id,
            status_completed: read_model.status_completed,
            planning_start_date: @clock.today,
            planning_end_date: read_model.planning_end_date,
            farm_name: read_model.farm_name,
            total_area: read_model.total_area,
            field_cultivations_count: read_model.field_cultivations_count,
            total_cost: read_model.total_cost,
            total_revenue: read_model.total_revenue,
            total_profit: read_model.total_profit,
            gantt_cultivation_rows: read_model.gantt_cultivation_rows,
            gantt_field_rows: read_model.gantt_field_rows,
            crop_palette_embed: read_model.crop_palette_embed,
            show_schedule_warning: read_model.show_schedule_warning
          )
        end
      end
    end
  end
end
