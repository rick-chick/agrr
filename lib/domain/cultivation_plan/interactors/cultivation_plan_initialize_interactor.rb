# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 農場・面積・作物選択から CultivationPlan / CultivationPlanCrop / CultivationPlanField を構築する。
      # 永続化は Gateway に委譲し、配分・日付計算は domain 側で行う。
      class CultivationPlanInitializeInteractor
        Result = Struct.new(:cultivation_plan, :errors, keyword_init: true) do
          def success?
            errors.empty?
          end
        end

        def initialize(
          farm:,
          total_area:,
          crops:,
          cultivation_plan_gateway:,
          plan_crop_gateway:,
          field_mutation_gateway:,
          clock:,
          logger:,
          user: nil,
          session_id: nil,
          plan_type: "public",
          plan_year: nil,
          plan_name: nil,
          planning_start_date: nil,
          planning_end_date: nil
        )
          @farm = farm
          @total_area = total_area
          @crops = crops
          @user = user
          @session_id = session_id
          @plan_type = plan_type
          @plan_year = plan_year
          @plan_name = plan_name
          @planning_start_date = planning_start_date
          @planning_end_date = planning_end_date
          @cultivation_plan_gateway = cultivation_plan_gateway
          @plan_crop_gateway = plan_crop_gateway
          @field_mutation_gateway = field_mutation_gateway
          @clock = clock
          @logger = logger
        end

        def call
          @logger.debug "🔍 [CultivationPlanInitializeInteractor] crops count: #{@crops.count}"
          @crops.each_with_index { |crop, i| @logger.debug "  - Crop #{i + 1}: #{crop.name} (ID: #{crop.id})" }

          @logger.info "🚀 [CultivationPlanInitializeInteractor] Starting plan creation with farm: #{@farm.name} (#{@farm.id}), crops: #{@crops.count}, total_area: #{@total_area}"

          if @total_area <= 0
            error_msg = "総面積は0より大きい値である必要があります (total_area: #{@total_area})"
            @logger.error "❌ CultivationPlan creation failed: #{error_msg}"
            return Result.new(cultivation_plan: nil, errors: [ error_msg ])
          end

          plan_entity = nil
          @cultivation_plan_gateway.within_transaction do
            plan_entity = create_plan_and_relations
          end

          @logger.info "✅ Added fields and crops to CultivationPlan ##{plan_entity.id}"
          Result.new(cultivation_plan: plan_entity, errors: [])
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          raise e
        rescue StandardError => e
          @logger.error "❌ CultivationPlan creation failed: #{e.message}"
          @logger.error e.backtrace.join("\n")
          Result.new(cultivation_plan: nil, errors: [ e.message ])
        end

        private

        def create_plan_and_relations
          planning_dates = resolve_planning_dates
          plan_name = resolve_plan_name
          user_id = @user&.id

          create_attrs = Dtos::CultivationPlanCreateAttrs.new(
            farm_id: @farm.id,
            user_id: user_id,
            total_area: @total_area,
            plan_type: @plan_type,
            session_id: @session_id,
            plan_year: @plan_type == "private" ? @plan_year : nil,
            plan_name: @plan_type == "private" ? plan_name : nil,
            planning_start_date: planning_dates[:start_date],
            planning_end_date: planning_dates[:end_date]
          )

          plan_entity = @cultivation_plan_gateway.create(attrs: create_attrs)
          create_plan_crops(plan_entity.id)
          create_plan_fields(plan_entity.id)
          @cultivation_plan_gateway.find_by_id(plan_entity.id)
        end

        def resolve_planning_dates
          if @plan_type == "private"
            return {
              start_date: @planning_start_date,
              end_date: @planning_end_date
            }
          end

          if @planning_start_date && @planning_end_date
            return {
              start_date: @planning_start_date,
              end_date: @planning_end_date
            }
          end

          Calculators::PlanningDateCalculator.calculate_public_planning_dates(as_of: @clock.today)
        end

        def resolve_plan_name
          return @plan_name if Domain::Shared.present?(@plan_name)

          @farm.name
        end

        def create_plan_crops(plan_id)
          @crops.each do |crop|
            @plan_crop_gateway.create_for_plan(
              attrs: Dtos::CultivationPlanPlanCropCreateAttrs.new(
                plan_id: plan_id,
                crop_id: crop.id,
                name: crop.name,
                variety: crop.variety,
                area_per_unit: crop.area_per_unit,
                revenue_per_area: crop.revenue_per_area
              )
            )
          end
        end

        def create_plan_fields(plan_id)
          if @total_area <= 0 || @crops.empty?
            @logger.warn "⚠️ [FieldsAllocation] Invalid parameters detected (total_area: #{@total_area}, crops: #{@crops.count}). Creating default field."
          end

          allocations = FieldsAllocation.new(@total_area, @crops).allocate
          allocations.each_with_index do |allocation, index|
            area = allocation[:area]
            next if Policies::CultivationPlanFieldPolicy.invalid_field_area?(field_area: area)

            @field_mutation_gateway.create_field(
              plan_id: plan_id,
              field_name: (index + 1).to_s,
              field_area: area,
              daily_fixed_cost: daily_cost(area)
            )
          end
        end

        def daily_cost(area)
          area * 1.0
        end
      end
    end
  end
end
