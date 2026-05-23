# frozen_string_literal: true

require "set"

module Adapters
  module CultivationPlan
    module Sessions
      # 公開プラン保存フロー（旧 Domain::CultivationPlan::Interactors::PlanSaveSession）。
      # 大量の AR 操作を含むため Adapter 層に置く。Domain 側からは
      # Domain::CultivationPlan::Gateways::PublicPlanSaveGateway インタフェース経由で呼ぶ。
      class PlanSaveSession
        include ActiveModel::Model

        class InvalidTaskScheduleItemError < StandardError; end

        class Result
          attr_accessor :success, :error_message, :new_plan
          attr_reader :skipped_items

          def initialize
            @success = false
            @error_message = nil
            @new_plan = nil
            @skipped_items = { farm: [], fields: [], crops: [], fertilizes: [], pests: [], agricultural_tasks: [], pesticides: [], interaction_rules: [] }
          end

          def success?
            success
          end

          def skipped?
            @skipped_items.values.any?(&:present?)
          end

          def add_skip(category, value)
            (@skipped_items[category] ||= []) << value
          end
        end

        attr_accessor :user, :session_data, :result

        def initialize(user:, session_data:, logger:, cultivation_plan_gateway:, crop_stage_copy_gateway:)
          @user = user.is_a?(::User) ? user : ::User.find(user.id)
          @session_data = session_data
          @logger = logger
          @cultivation_plan_gateway = cultivation_plan_gateway
          @crop_stage_copy_gateway = crop_stage_copy_gateway
          @result = Result.new
        end

        def call
          @logger.debug I18n.t("services.plan_save_service.debug.session_data_received", data: @session_data.inspect)

          ctx = PlanSaveContext.new(user: @user, session_data: @session_data, result: @result)
          ctx.crop_stage_copy_gateway = @crop_stage_copy_gateway
          farm_mapper = Mappers::FarmMapper.new(ctx)

          @cultivation_plan_gateway.within_transaction do
            farm = farm_mapper.create_or_get_user_farm

            fields = Mappers::FieldMapper.new(ctx).create_user_fields(farm)
            crops = Mappers::CropMapper.new(ctx).create_user_crops_from_plan
            pests = Mappers::PestMapper.new(ctx).copy_pests_for_region(farm.region)
            agricultural_tasks = Mappers::AgriculturalTaskMapper.new(ctx).copy_agricultural_tasks_for_region(farm.region)
            interaction_rules = Mappers::InteractionRuleMapper.new(ctx).copy_interaction_rules_for_region(farm.region)
            fertilizes = Mappers::FertilizeMapper.new(ctx).copy_fertilizes_for_region(farm.region)
            pesticides = Mappers::PesticideMapper.new(ctx).copy_pesticides_for_region(farm.region)

            existing_plan = farm_mapper.find_existing_private_plan(farm)

            if existing_plan
              @logger.info "♻️ [PlanSaveService] Existing private plan detected (##{existing_plan.id}), skipping plan copy"
              @result.add_skip(:plan, existing_plan.id)
              @result.new_plan = existing_plan
              @result.success = true
              return @result
            end

            plan_gateway = ::Adapters::CultivationPlan::Gateways::PlanCopyActiveRecordGateway.new(ctx, logger: @logger)
            new_plan = plan_gateway.copy_cultivation_plan(farm, crops)

            plan_gateway.establish_master_data_relationships(
              farm, crops, fields, pests, agricultural_tasks, fertilizes, pesticides, interaction_rules
            )

            ::Adapters::CultivationPlan::Gateways::CropTaskScheduleBlueprintActiveRecordGateway.new(ctx).copy_for_user_crops
            field_cultivation_map = plan_gateway.copy_plan_relations(new_plan)
            plan_gateway.copy_task_schedules(new_plan, field_cultivation_map)

            @logger.info I18n.t("services.plan_save_service.messages.service_completed")
            @result.success = true
            @result.new_plan = new_plan
          end

          @result
        rescue InvalidTaskScheduleItemError => e
          @logger.error I18n.t("services.plan_save_service.errors.task_schedule_invalid", error: e.message) if I18n.exists?("services.plan_save_service.errors.task_schedule_invalid")
          @logger.error e.backtrace.join("\n")
          raise Domain::Shared::Exceptions::InvalidTaskScheduleItem, e.message
        rescue => e
          @logger.error I18n.t("services.plan_save_service.errors.unknown_error", error: e.message)
          @logger.error e.backtrace.join("\n")
          @result.error_message = e.message
          @result
        end
      end
    end
  end
end
