# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 既存天気予測と agrr allocate を用いて FieldCultivation を再構築する。
      # 旧 app/services/cultivation_plan_optimizer.rb を domain へ移行（T-031）。
      class CultivationPlanOptimizeInteractor
        class WeatherDataNotFoundError < StandardError; end

        def initialize(cultivation_plan, channel_class, allocation_gateway: nil)
          @cultivation_plan = cultivation_plan
          @channel_class = channel_class
          @allocation_gateway = allocation_gateway || ::Adapters::Agrr::PlanAllocationGatewayAdapter.new
        end

        def call
          @cultivation_plan.start_optimizing!
          @current_phase = nil

          begin
            weather_location = @cultivation_plan.farm&.weather_location
            unless weather_location
              error_message = "農場にWeatherLocationが設定されていません。気象データを取得してください。"
              Rails.logger.error "❌ [Optimizer] #{error_message}"
              raise WeatherDataNotFoundError, error_message
            end

            _, planning_end_date = calculate_planning_period
            weather_prediction_service = ::WeatherPredictionService.new(
              weather_location: weather_location,
              farm: @cultivation_plan.farm
            )
            existing_prediction = weather_prediction_service.get_existing_prediction(
              target_end_date: planning_end_date,
              cultivation_plan: @cultivation_plan
            )

            unless existing_prediction
              error_message = "天気予測データが存在しません。計画作成時に天気予測が実行されていません。"
              Rails.logger.error "❌ [Optimizer] #{error_message}"
              raise WeatherDataNotFoundError, error_message
            end

            Rails.logger.info "♻️ [Optimizer] Using existing prediction data"
            weather_info = existing_prediction

            @current_phase = "optimizing"
            @cultivation_plan.phase_optimizing!(@channel_class)

            fields_data, crops_data = prepare_allocation_data(weather_info[:target_end_date])

            interaction_rules = prepare_interaction_rules

            Rails.logger.info "🚀 [AGRR] Starting single allocation for #{fields_data.count} fields and #{crops_data.count} crops"
            if interaction_rules&.any?
              Rails.logger.info "📋 [AGRR] Using #{interaction_rules.count} interaction rules"
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

            Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
            true
          rescue ::Agrr::BaseGatewayV2::NoAllocationCandidatesError => e
            Rails.logger.error "❌ [Optimizer] AGRR allocation failed: #{e.message}"
            Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          rescue ::Agrr::BaseGatewayV2::ExecutionError => e
            Rails.logger.error "❌ [Optimizer] AGRR execution failed: #{e.message}"
            Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          rescue StandardError => e
            Rails.logger.error "❌ [Optimizer] Unexpected error at phase: #{@current_phase || 'unknown'}: #{e.message}"
            Rails.logger.info "🔄 [Optimizer] Re-raising error to job level"
            raise e
          end
        end

        private

        def calculate_planning_period
          if @cultivation_plan.field_cultivations.any?
            start_date = @cultivation_plan.calculated_planning_start_date
            end_date = @cultivation_plan.calculated_planning_end_date
            [ start_date, end_date ]
          else
            if @cultivation_plan.plan_type_private?
              [
                Date.current.beginning_of_year,
                Date.new(Date.current.year + 1, 12, 31)
              ]
            else
              end_date = if @cultivation_plan.respond_to?(:prediction_target_end_date)
                @cultivation_plan.prediction_target_end_date
              else
                Date.new(Date.current.year + 1, 12, 31)
              end

              [
                Date.current,
                end_date
              ]
            end
          end
        end

        def prepare_interaction_rules
          farm_region = @cultivation_plan.farm.region

          rules = if @cultivation_plan.user_id
            ::InteractionRule.where(
              "((user_id = ? AND is_reference = ?) OR is_reference = ?) AND region = ?",
              @cultivation_plan.user_id,
              false,
              true,
              farm_region
            )
          else
            ::InteractionRule.reference.where(region: farm_region)
          end

          rules_array = ::InteractionRule.to_agrr_format_array(rules)

          return nil if rules_array.empty?

          rules_array
        end

        def prepare_allocation_data(evaluation_end)
          Rails.logger.info "🗓️  [AGRR] Evaluation period: #{Date.current} to #{evaluation_end}"

          cultivation_plan_crops = @cultivation_plan.cultivation_plan_crops.to_a
          Rails.logger.debug "🔍 [CultivationPlanOptimizeInteractor] cultivation_plan_crops count: #{cultivation_plan_crops.count}"
          cultivation_plan_crops.each { |cpc| Rails.logger.debug "  - CultivationPlanCrop: #{cpc.name} (Crop ID: #{cpc.crop_id})" }

          fields_data = []
          crops_data = []
          crops_collection = {}

          cultivation_plan_crops.each do |cpc|
            crop = cpc.crop

            Rails.logger.debug "🌾 [AGRR] Processing crop: #{crop.name} (ID: #{crop.id})"

            crop_key = crop.id.to_s
            unless crops_collection[crop_key]
              crops_collection[crop_key] = crop
            end
          end

          crop_count = crops_collection.size

          field_count = [ crop_count, 1 ].max

          total_area = @cultivation_plan.total_area

          area_per_field = total_area / field_count.to_f

          Rails.logger.info "📊 [AGRR] Total area: #{total_area}㎡, Crop count: #{crop_count}, Field count: #{field_count} (1 field per crop)"
          Rails.logger.info "📊 [AGRR] Area per field: #{area_per_field.round(2)}㎡"

          field_count.times do |i|
            field_id = i + 1
            fields_data << {
              "field_id" => field_id,
              "name" => "圃場#{i + 1}",
              "area" => area_per_field,
              "daily_fixed_cost" => 10.0
            }
          end

          crops_collection.each do |_crop_key, crop|
            crop_requirement = crop.to_agrr_requirement

            revenue_per_area = crop.revenue_per_area || 5000.0

            original_max_revenue = crop_requirement["crop"]["max_revenue"]

            adjusted_max_revenue = (revenue_per_area * total_area * 3) / crop_count.to_f

            crop_requirement["crop"]["max_revenue"] = adjusted_max_revenue

            Rails.logger.info "🔧 [AGRR] Crop '#{crop.name}' - revenue_per_area: ¥#{revenue_per_area}/㎡, " \
                              "max_revenue: ¥#{original_max_revenue.round(0)} → ¥#{adjusted_max_revenue.round(0)} " \
                              "(limited to ~#{(adjusted_max_revenue / revenue_per_area).round(1)}㎡, 3 crops)"

            crops_data << crop_requirement
          end

          [ fields_data, crops_data ]
        end

        def distribute_allocation_results(allocation_result)
          @cultivation_plan.field_cultivations.destroy_all
          Rails.logger.info "🗑️  [AGRR] Cleared existing FieldCultivations for CultivationPlan ##{@cultivation_plan.id}"

          Rails.logger.info "🔄 [AGRR] Keeping existing CultivationPlanFields and CultivationPlanCrops for CultivationPlan ##{@cultivation_plan.id}"

          field_schedules = allocation_result[:field_schedules] || []

          field_schedules.each do |schedule|
            field_id = schedule["field_id"]

            if schedule["allocations"].blank?
              Rails.logger.warn "⚠️  [AGRR] No allocations for field #{field_id}"
              next
            end

            allocations = schedule["allocations"]

            allocations.each do |allocation|
              create_field_cultivation_from_allocation(allocation, field_id)
            end

            Rails.logger.info "✅ [AGRR] Created #{allocations.size} FieldCultivations for field #{field_id}"
          end
        end

        def create_field_cultivation_from_allocation(allocation, field_id)
          crop_id = allocation["crop_id"]
          crop_name = allocation["crop_name"]
          crop_variety = allocation["variety"]

          field_number = field_id.split("_").last
          field_name = field_number

          field_cultivation = @cultivation_plan.field_cultivations.create!(
            cultivation_plan_field_id: create_or_find_cultivation_plan_field(field_name, allocation["area_used"]),
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
          )

          Rails.logger.info "🌱 [AGRR] Created FieldCultivation ##{field_cultivation.id}: #{crop_name} (#{crop_variety}) " \
                            "#{allocation['start_date']} - #{allocation['completion_date']} " \
                            "(#{allocation['area_used']}㎡, ¥#{allocation['profit']})"

          field_cultivation
        end

        def create_or_find_cultivation_plan_field(field_name, area)
          field = @cultivation_plan.cultivation_plan_fields.find_or_create_by!(
            name: field_name
          ) do |f|
            f.area = area
            f.daily_fixed_cost = 10.0
          end
          field.id
        end

        def find_cultivation_plan_crop_by_crop_id(crop_id, crop_name)
          existing_cpc = @cultivation_plan.cultivation_plan_crops.find_by(crop_id: crop_id)

          if existing_cpc
            Rails.logger.debug "♻️ [AGRR] Found existing CultivationPlanCrop: #{crop_name} (ID: #{existing_cpc.id}, Crop ID: #{existing_cpc.crop_id})"
            existing_cpc.id
          else
            Rails.logger.error "❌ [AGRR] CultivationPlanCrop not found for crop_id: #{crop_id} (#{crop_name})"
            Rails.logger.error "❌ [AGRR] Available CultivationPlanCrops: #{@cultivation_plan.cultivation_plan_crops.pluck(:crop_id, :name)}"
            raise "CultivationPlanCrop not found for crop_id: #{crop_id}. This indicates a data integrity issue."
          end
        end

        def update_cultivation_plan_with_results(allocation_result)
          @cultivation_plan.update!(
            total_profit: allocation_result[:total_profit],
            total_revenue: allocation_result[:total_revenue],
            total_cost: allocation_result[:total_cost],
            optimization_time: allocation_result[:optimization_time],
            algorithm_used: allocation_result[:algorithm_used],
            is_optimal: allocation_result[:is_optimal],
            optimization_summary: allocation_result[:summary].to_json
          )

          Rails.logger.info "📊 [AGRR] CultivationPlan ##{@cultivation_plan.id} updated with optimization results: " \
                            "profit=¥#{allocation_result[:total_profit]}, revenue=¥#{allocation_result[:total_revenue]}, " \
                            "cost=¥#{allocation_result[:total_cost]}"
        end
      end
    end
  end
end
