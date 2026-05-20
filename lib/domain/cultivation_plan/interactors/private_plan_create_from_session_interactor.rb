# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # セッション起点の私有計画作成。API `PrivatePlanInitializeFromSelectionInteractor` と同 Gateway 経路。
      class PrivatePlanCreateFromSessionInteractor
        def initialize(
          output_port:,
          cultivation_plan_gateway:,
          logger:,
          translator:,
          clock:,
          session_id_generator:,
          post_create_job_chain:,
          select_crop_context_runner:
        )
          @output_port = output_port
          @cultivation_plan_gateway = cultivation_plan_gateway
          @logger = logger
          @translator = translator
          @clock = clock
          @session_id_generator = session_id_generator
          @post_create_job_chain = post_create_job_chain
          @select_crop_context_runner = select_crop_context_runner
        end

        def call(input_dto)
          unless Domain::Shared.present?(input_dto.farm_id)
            @output_port.on_missing_session
            return
          end

          farm = @cultivation_plan_gateway.find_farm(input_dto.farm_id, input_dto.user)
          unless farm
            @output_port.on_restart
            return
          end

          unless Domain::Shared.present?(input_dto.crop_ids)
            notify_no_crops_after_context(farm.id)
            return
          end

          crops = @cultivation_plan_gateway.find_crops(input_dto.crop_ids, input_dto.user)
          if crops.empty?
            notify_no_crops_after_context(farm.id)
            return
          end

          existing = @cultivation_plan_gateway.find_existing(farm, input_dto.user)
          if existing
            @output_port.on_existing_plan(plan_id: existing.id, plan_year: existing.plan_year)
            return
          end

          plan_name = input_dto.plan_name.to_s.strip.empty? ? farm.name : input_dto.plan_name.to_s.strip
          total_area = resolved_total_area(input_dto, farm)
          session_id = @session_id_generator.call

          result = @cultivation_plan_gateway.initialize_plan_from_selection(
            farm: farm,
            total_area: total_area,
            crops: crops,
            user: input_dto.user,
            session_id: session_id,
            plan_type: "private",
            plan_year: nil,
            plan_name: plan_name,
            planning_start_date: Domain::Shared::DateCalendar.beginning_of_year(@clock.today),
            planning_end_date: Date.new(@clock.today.year + 1, 12, 31)
          )

          unless result.success? && result.cultivation_plan
            msg = Domain::Shared.present?(result.errors) ? result.errors.join(", ") : @translator.t("public_plans.save.error")
            @logger.error("❌ [PrivatePlanCreateFromSessionInteractor] Initialize failed: #{msg}")
            @output_port.on_initialize_failed(message: msg)
            return
          end

          plan_id = result.cultivation_plan.id
          @logger.info("✅ [PrivatePlanCreateFromSessionInteractor] CultivationPlan created: #{plan_id}")
          @post_create_job_chain.enqueue_for_plan(plan_id: plan_id)
          @output_port.on_success(plan_id: plan_id)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("❌ [PrivatePlanCreateFromSessionInteractor] #{e.class}: #{e.message}")
          @output_port.on_initialize_failed(message: e.message)
        end

        private

        def notify_no_crops_after_context(farm_id)
          @select_crop_context_runner.call(farm_id: farm_id)
          return if @select_crop_context_runner.response_committed?

          @output_port.on_no_crops_selected
        end

        def resolved_total_area(input_dto, farm)
          if Domain::Shared.present?(input_dto.total_area)
            input_dto.total_area.to_f
          else
            @cultivation_plan_gateway.total_field_area_for_farm(farm.id, input_dto.user)
          end
        end
      end
    end
  end
end
