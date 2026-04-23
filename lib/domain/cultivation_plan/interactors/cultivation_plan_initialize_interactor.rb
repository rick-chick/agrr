# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 農場・面積・作物選択から CultivationPlan / CultivationPlanCrop / CultivationPlanField を構築する。
      # 旧 app/services/cultivation_plan_creator.rb を domain へ移行（T-031）。永続化は Gateway に委譲。
      class CultivationPlanInitializeInteractor
        Result = Struct.new(:cultivation_plan, :errors, keyword_init: true) do
          def success?
            errors.empty?
          end
        end

        def initialize(farm:, total_area:, crops:, user: nil, session_id: nil, plan_type: "public", plan_year: nil, plan_name: nil, planning_start_date: nil, planning_end_date: nil, gateway: nil,
                       logger: Rails.logger)
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
          @gateway = gateway || Domain::CultivationPlan::Gateways::CultivationPlanGateway.default
          @logger = logger
        end

        def call
          @logger.debug "🔍 [CultivationPlanInitializeInteractor] crops count: #{@crops.count}"
          @crops.each_with_index { |crop, i| @logger.debug "  - Crop #{i + 1}: #{crop.name} (ID: #{crop.id})" }

          @logger.info "🚀 [CultivationPlanInitializeInteractor] Starting plan creation with farm: #{@farm.name} (#{@farm.id}), crops: #{@crops.count}, total_area: #{@total_area}"

          @gateway.initialize_plan_from_selection(
            farm: @farm,
            total_area: @total_area,
            crops: @crops,
            user: @user,
            session_id: @session_id,
            plan_type: @plan_type,
            plan_year: @plan_year,
            plan_name: @plan_name,
            planning_start_date: @planning_start_date,
            planning_end_date: @planning_end_date
          )
        end
      end
    end
  end
end
