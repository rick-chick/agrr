# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Sessions
      # 公開プラン保存の永続化ステップ（Adapter）。オーケストレーションは Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor。
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

          def add_skip(category, value)
            (@skipped_items[category] ||= []) << value
          end
        end

        attr_accessor :user, :session_data, :result

        def initialize(
          user:,
          session_data:,
          logger:,
          cultivation_plan_gateway:,
          crop_stage_copy_interactor:,
          blueprint_copy_factory:,
          template_copy_gateway:,
          plan_save_persist_orchestrator:,
          plan_save_farm_gateway:,
          plan_save_ensure_user_fields_interactor:,
          plan_save_ensure_user_crops_interactor:,
          plan_save_ensure_user_pests_interactor:,
          plan_save_field_gateway:,
          plan_save_user_crop_gateway:,
          plan_save_user_pest_gateway:,
          own_transaction: true
        )
          @user = user.is_a?(::User) ? user : ::User.find(user.id)
          @session_data = session_data
          @logger = logger
          @cultivation_plan_gateway = cultivation_plan_gateway
          @crop_stage_copy_interactor = crop_stage_copy_interactor
          @blueprint_copy_factory = blueprint_copy_factory
          @template_copy_gateway = template_copy_gateway
          @plan_save_persist_orchestrator = plan_save_persist_orchestrator
          @plan_save_farm_gateway = plan_save_farm_gateway
          @plan_save_ensure_user_fields_interactor = plan_save_ensure_user_fields_interactor
          @plan_save_ensure_user_crops_interactor = plan_save_ensure_user_crops_interactor
          @plan_save_ensure_user_pests_interactor = plan_save_ensure_user_pests_interactor
          @plan_save_field_gateway = plan_save_field_gateway
          @plan_save_user_crop_gateway = plan_save_user_crop_gateway
          @plan_save_user_pest_gateway = plan_save_user_pest_gateway
          @own_transaction = own_transaction
          @result = Result.new
        end

        def call
          @logger.debug I18n.t("services.plan_save_service.debug.session_data_received", data: @session_data.inspect)

          if @own_transaction
            @cultivation_plan_gateway.within_transaction { run_persist_steps }
          else
            run_persist_steps
          end

          @result
        rescue InvalidTaskScheduleItemError => e
          @logger.error I18n.t("services.plan_save_service.errors.task_schedule_invalid", error: e.message) if I18n.exists?("services.plan_save_service.errors.task_schedule_invalid")
          @logger.error e.backtrace.join("\n")
          raise Domain::Shared::Exceptions::InvalidTaskScheduleItem, e.message
        rescue StandardError => e
          @logger.error I18n.t("services.plan_save_service.errors.unknown_error", error: e.message)
          @logger.error e.backtrace.join("\n")
          @result.error_message = e.message
          @result
        end

        private

        def run_persist_steps
          ctx = PlanSaveContext.new(user: @user, session_data: @session_data, result: @result)

          farm_output = @plan_save_persist_orchestrator.ensure_user_farm!(
            user_id: @user.id,
            session_data: @session_data
          )
          ctx.farm_reused = farm_output.farm_reused
          ctx.result.add_skip(:farm, farm_output.farm_id) if farm_output.farm_reused
          farm = @plan_save_farm_gateway.find_owned_farm_record(
            user_id: @user.id,
            farm_id: farm_output.farm_id
          )
          unless farm
            raise Domain::Shared::Exceptions::RecordNotFound,
                  "User farm not found: #{farm_output.farm_id}"
          end
          farm_region = farm_output.farm_region

          field_output = @plan_save_ensure_user_fields_interactor.call(
            Domain::CultivationPlan::Dtos::PlanSaveEnsureUserFieldsInput.new(
              user_id: @user.id,
              farm_id: farm_output.farm_id,
              farm_reused: farm_output.farm_reused,
              field_data: field_data_from_session
            )
          )
          field_output.skipped_field_ids.each { |id| @result.add_skip(:fields, id) }
          fields = @plan_save_field_gateway.list_by_ids(ids: field_output.field_ids, user_id: @user.id)

          plan_id = @session_data[:plan_id] || @session_data["plan_id"]
          crop_output = @plan_save_ensure_user_crops_interactor.call(
            Domain::CultivationPlan::Dtos::PlanSaveEnsureUserCropsInput.new(
              user_id: @user.id,
              plan_id: plan_id
            )
          )
          crop_output.skipped_crop_ids.each { |id| @result.add_skip(:crops, id) }
          ctx.reference_crop_id_to_user_crop_id = crop_output.reference_crop_id_to_user_crop_id
          ctx.ref_cpc_id_to_user_crop_id = crop_output.ref_cpc_id_to_user_crop_id
          ctx.reference_crop_groups = crop_output.reference_crop_groups

          copy_crop_stages_for_pairs!(crop_output.stage_copy_pairs)

          crops = @plan_save_user_crop_gateway.list_by_ids(ids: crop_output.user_crop_ids)

          pest_output = @plan_save_ensure_user_pests_interactor.call(
            Domain::CultivationPlan::Dtos::PlanSaveEnsureUserPestsInput.new(
              user_id: @user.id,
              plan_id: plan_id,
              region: farm_region,
              reference_crop_id_to_user_crop_id: crop_output.reference_crop_id_to_user_crop_id
            )
          )
          pest_output.skipped_pest_ids.each { |id| @result.add_skip(:pests, id) }
          ctx.reference_pest_id_to_user_pest_id = pest_output.reference_pest_id_to_user_pest_id
          pests = @plan_save_user_pest_gateway.list_by_ids(ids: pest_output.user_pest_ids)
          agricultural_tasks = Mappers::AgriculturalTaskMapper.new(ctx).copy_agricultural_tasks_for_region(farm_region)
          interaction_rules = Mappers::InteractionRuleMapper.new(ctx).copy_interaction_rules_for_region(farm_region)
          fertilizes = Mappers::FertilizeMapper.new(ctx).copy_fertilizes_for_region(farm_region)
          pesticides = Mappers::PesticideMapper.new(ctx).copy_pesticides_for_region(farm_region)

          existing_plan = @plan_save_farm_gateway.find_owned_private_plan_record(
            user_id: @user.id,
            farm_id: farm.id
          )

          if existing_plan
            @logger.info "♻️ [PlanSaveService] Existing private plan detected (##{existing_plan.id}), skipping plan copy"
            @result.add_skip(:plan, existing_plan.id)
            @result.new_plan = existing_plan
            @result.success = true
            return
          end

          tpl_gw = @template_copy_gateway
          new_plan = tpl_gw.copy_cultivation_plan(ctx: ctx, farm: farm, crops: crops)

          tpl_gw.establish_master_data_relationships(
            ctx: ctx,
            farm: farm,
            crops: crops,
            fields: fields,
            pests: pests,
            agricultural_tasks: agricultural_tasks,
            fertilizes: fertilizes,
            pesticides: pesticides,
            interaction_rules: interaction_rules
          )

          @blueprint_copy_factory.build_interactor(ctx).call(
            Domain::CultivationPlan::Dtos::CropTaskScheduleBlueprintCopyInput.new(
              reference_crop_id_to_user_crop_id: ctx.reference_crop_id_to_user_crop_id
            )
          )
          field_cultivation_map = tpl_gw.copy_plan_relations(ctx: ctx, new_plan: new_plan)
          tpl_gw.copy_task_schedules(ctx: ctx, new_plan: new_plan, field_cultivation_map: field_cultivation_map)

          @logger.info I18n.t("services.plan_save_service.messages.service_completed")
          @result.success = true
          @result.new_plan = new_plan
        end

        def copy_crop_stages_for_pairs!(pairs)
          pairs.each do |pair|
            @crop_stage_copy_interactor.call(
              Domain::Crop::Dtos::CropStageCopyInput.new(
                reference_crop_id: pair.reference_crop_id,
                new_crop_id: pair.new_crop_id
              )
            )
          end
        rescue StandardError => e
          @logger.error(
            I18n.t("services.plan_save_service.errors.crop_stage_copy_failed", errors: e.message)
          )
          raise e
        end

        def field_data_from_session
          raw = @session_data[:field_data] || @session_data["field_data"]
          return [] unless raw&.any?

          raw.filter_map do |row|
            Domain::CultivationPlan::Dtos::PublicPlanSaveFieldDatum.from_row(row)
          end
        end
      end
    end
  end
end
