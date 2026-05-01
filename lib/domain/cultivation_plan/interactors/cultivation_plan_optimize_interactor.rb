# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 既存天気予測と agrr allocate を用いて FieldCultivation を再構築する。
      # 旧 app/services/cultivation_plan_optimizer.rb を domain へ移行（T-031）。
      class CultivationPlanOptimizeInteractor
        class WeatherDataNotFoundError < StandardError; end

        def initialize(
          plan_id:,
          channel_class:,
          allocation_gateway:,
          interaction_rule_gateway:,
          cultivation_plan_gateway:,
          logger:,
          weather_prediction_interactor_factory:
        )
          @plan_id = plan_id
          @channel_class = channel_class
          @allocation_gateway = allocation_gateway
          @interaction_rule_gateway = interaction_rule_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @logger = logger
          @weather_prediction_interactor_factory = weather_prediction_interactor_factory
        end

        def call
          load_snapshot!
          @cultivation_plan_gateway.update_phase(@plan_id, :start_optimizing)
          @cultivation_plan_gateway.update_phase(@plan_id, :phase_optimizing, @channel_class)
          @current_phase = nil

          begin
            unless @snapshot.weather_location_present
              error_message = "農場にWeatherLocationが設定されていません。気象データを取得してください。"
              @logger.error "❌ [Optimizer] #{error_message}"
              raise WeatherDataNotFoundError, error_message
            end

            _, planning_end_date = calculate_planning_period
            weather_prediction_service = @weather_prediction_interactor_factory.call(
              weather_location: @snapshot.weather_location_input,
              farm: @snapshot.farm_weather_input
            )
            plan_weather = Domain::WeatherData::Dtos::CultivationPlanWeatherDto.new(
              id: @snapshot.plan_id,
              prediction_target_end_date: @snapshot.prediction_target_end_date,
              calculated_planning_end_date: @snapshot.calculated_planning_end_date,
              predicted_weather_data: @snapshot.predicted_weather_data
            )
            existing_prediction = weather_prediction_service.get_existing_prediction(
              target_end_date: planning_end_date,
              cultivation_plan_weather: plan_weather
            )

            unless existing_prediction
              error_message = "天気予測データが存在しません。計画作成時に天気予測が実行されていません。"
              @logger.error "❌ [Optimizer] #{error_message}"
              raise WeatherDataNotFoundError, error_message
            end

            @logger.info "♻️ [Optimizer] Using existing prediction data"
            weather_info = existing_prediction

            @current_phase = "optimizing"

            fields_data, crops_data = prepare_allocation_data(weather_info[:target_end_date])

            interaction_rules = prepare_interaction_rules

            @logger.info "🚀 [AGRR] Starting single allocation for #{fields_data.count} fields and #{crops_data.count} crops"
            if interaction_rules&.any?
              @logger.info "📋 [AGRR] Using #{interaction_rules.count} interaction rules"
            end

            planning_start, planning_end = calculate_planning_period

            allocation_result = @allocation_gateway.allocate(
              fields: fields_data,
              crops: crops_data,
              weather_data: weather_info[:data],
              planning_start: planning_start,
              planning_end: planning_end,
              interaction_rules: interaction_rules
            )

            distribute_allocation_results(allocation_result)

            update_cultivation_plan_with_results(allocation_result)

            @logger.info "✅ CultivationPlan ##{@plan_id} optimization completed"
            true
          rescue Domain::CultivationPlan::Errors::AllocationNoCandidatesError => e
            @logger.error "❌ [Optimizer] AGRR allocation failed: #{e.message}"
            @logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          rescue Domain::CultivationPlan::Errors::AllocationExecutionError => e
            @logger.error "❌ [Optimizer] AGRR execution failed: #{e.message}"
            @logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          rescue StandardError => e
            @logger.error "❌ [Optimizer] Unexpected error at phase: #{@current_phase || 'unknown'}: #{e.message}"
            @logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          end
        end

        private

        def load_snapshot!
          @snapshot = @cultivation_plan_gateway.optimization_plan_snapshot(@plan_id)
        end

        def calculate_planning_period
          if @cultivation_plan_gateway.field_cultivations_present?(@plan_id)
            start_date = @snapshot.calculated_planning_start_date
            end_date = @snapshot.calculated_planning_end_date
            [ start_date, end_date ]
          else
            if @snapshot.plan_type_private
              [
                Date.current.beginning_of_year,
                Date.new(Date.current.year + 1, 12, 31)
              ]
            else
              end_date = @snapshot.prediction_target_end_date || Date.new(Date.current.year + 1, 12, 31)

              [
                Date.current,
                end_date
              ]
            end
          end
        end

        def prepare_interaction_rules
          @interaction_rule_gateway.agrr_rules_for_cultivation_plan_id(@plan_id)
        end

        def prepare_allocation_data(evaluation_end)
          @logger.info "🗓️  [AGRR] Evaluation period: #{Date.current} to #{evaluation_end}"

          cultivation_plan_crops = @cultivation_plan_gateway.cultivation_plan_crops_with_crop(@plan_id)
          @logger.debug "🔍 [CultivationPlanOptimizeInteractor] cultivation_plan_crops count: #{cultivation_plan_crops.count}"
          cultivation_plan_crops.each do |cpc|
            @logger.debug "  - CultivationPlanCrop: #{cpc.name} (Crop ID: #{cpc.crop_id})"
          end

          fields_data = []
          crops_data = []
          crops_collection = {}

          cultivation_plan_crops.each do |cpc|
            @logger.debug "🌾 [AGRR] Processing crop: #{cpc.crop_name} (ID: #{cpc.crop_id})"

            crop_key = cpc.crop_id.to_s
            unless crops_collection[crop_key]
              crops_collection[crop_key] = cpc
            end
          end

          crop_count = crops_collection.size

          field_count = [ crop_count, 1 ].max

          total_area = @snapshot.total_area

          area_per_field = total_area / field_count.to_f

          @logger.info "📊 [AGRR] Total area: #{total_area}㎡, Crop count: #{crop_count}, Field count: #{field_count} (1 field per crop)"
          @logger.info "📊 [AGRR] Area per field: #{area_per_field.round(2)}㎡"

          field_count.times do |i|
            field_id = i + 1
            fields_data << {
              "field_id" => field_id,
              "name" => "圃場#{i + 1}",
              "area" => area_per_field,
              "daily_fixed_cost" => 10.0
            }
          end

          crops_collection.each do |_crop_key, cpc|
            crop_requirement = cpc.agrr_requirement.deep_dup

            revenue_per_area = cpc.revenue_per_area || 5000.0

            original_max_revenue = crop_requirement["crop"]["max_revenue"]

            adjusted_max_revenue = (revenue_per_area * total_area * 3) / crop_count.to_f

            crop_requirement["crop"]["max_revenue"] = adjusted_max_revenue

            @logger.info "🔧 [AGRR] Crop '#{cpc.crop_name}' - revenue_per_area: ¥#{revenue_per_area}/㎡, " \
                              "max_revenue: ¥#{original_max_revenue.round(0)} → ¥#{adjusted_max_revenue.round(0)} " \
                              "(limited to ~#{(adjusted_max_revenue / revenue_per_area).round(1)}㎡, 3 crops)"

            crops_data << crop_requirement
          end

          [ fields_data, crops_data ]
        end

        def distribute_allocation_results(allocation_result)
          @cultivation_plan_gateway.clear_field_cultivations(@plan_id)
          @logger.info "🗑️  [AGRR] Cleared existing FieldCultivations for CultivationPlan ##{@plan_id}"

          @logger.info "🔄 [AGRR] Keeping existing CultivationPlanFields and CultivationPlanCrops for CultivationPlan ##{@plan_id}"

          field_schedules = allocation_result[:field_schedules] || []

          field_schedules.each do |schedule|
            field_id = schedule["field_id"]

            if schedule["allocations"].blank?
              @logger.warn "⚠️  [AGRR] No allocations for field #{field_id}"
              next
            end

            allocations = schedule["allocations"]

            allocations.each do |allocation|
              create_field_cultivation_from_allocation(allocation, field_id)
            end

            @logger.info "✅ [AGRR] Created #{allocations.size} FieldCultivations for field #{field_id}"
          end
        end

        def create_field_cultivation_from_allocation(allocation, field_id)
          crop_id = allocation["crop_id"]
          crop_name = allocation["crop_name"]
          crop_variety = allocation["variety"]

          field_number = field_id.split("_").last
          field_name = field_number

          field_cultivation = @cultivation_plan_gateway.create_field_cultivation(
            plan_id: @plan_id,
            attrs: {
              cultivation_plan_field_id: upsert_cultivation_plan_field(field_name, allocation["area_used"]),
              cultivation_plan_crop_id: find_cultivation_plan_crop_by_crop_id(crop_id, crop_name),
              area: allocation["area_used"],
              start_date: Date.parse(allocation["start_date"]),
              completion_date: Date.parse(allocation["completion_date"]),
              cultivation_days: allocation["growth_days"],
              estimated_cost: allocation["total_cost"],
              status: :completed,
              optimization_result: {
                allocation_id: allocation["allocation_id"],
                expected_revenue: allocation["expected_revenue"],
                profit: allocation["profit"],
                raw: allocation
              }
            }
          )

          @logger.info "🌱 [AGRR] Created FieldCultivation ##{field_cultivation.id}: #{crop_name} (#{crop_variety}) " \
                            "#{allocation['start_date']} - #{allocation['completion_date']} " \
                            "(#{allocation['area_used']}㎡, ¥#{allocation['profit']})"

          field_cultivation
        end

        def upsert_cultivation_plan_field(field_name, area)
          @cultivation_plan_gateway.upsert_cultivation_plan_field(
            plan_id: @plan_id,
            name: field_name,
            area: area,
            daily_fixed_cost: 10.0
          )
        end

        def find_cultivation_plan_crop_by_crop_id(crop_id, crop_name)
          id = @cultivation_plan_gateway.find_plan_crop_id_by_crop_id!(@plan_id, crop_id)
          @logger.debug "♻️ [AGRR] Found existing CultivationPlanCrop: #{crop_name} (Crop ID: #{crop_id})"
          id
        rescue StandardError => e
          @logger.error "❌ [AGRR] CultivationPlanCrop not found for crop_id: #{crop_id} (#{crop_name})"
          @logger.error "❌ [AGRR] #{e.message}"
          raise e
        end

        def update_cultivation_plan_with_results(allocation_result)
          @cultivation_plan_gateway.apply_optimization_result(
            plan_id: @plan_id,
            attrs: {
              total_profit: allocation_result[:total_profit],
              total_revenue: allocation_result[:total_revenue],
              total_cost: allocation_result[:total_cost],
              optimization_time: allocation_result[:optimization_time],
              algorithm_used: allocation_result[:algorithm_used],
              is_optimal: allocation_result[:is_optimal],
              optimization_summary: allocation_result[:summary].to_json
            }
          )

          @logger.info "📊 [AGRR] CultivationPlan ##{@plan_id} updated with optimization results: " \
                            "profit=¥#{allocation_result[:total_profit]}, revenue=¥#{allocation_result[:total_revenue]}, " \
                            "cost=¥#{allocation_result[:total_cost]}"
        end
      end
    end
  end
end
