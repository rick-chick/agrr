# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 農場・作物選択から私有計画を初期化し作成（private-plan-create-contract 準拠の分岐）。
      class PrivatePlanInitializeFromSelectionInteractor
        def initialize(
          output_port:,
          cultivation_plan_gateway:,
          logger:,
          translator:,
          clock:,
          session_id_generator:,
          job_chain_enqueuer:
        )
          @output_port = output_port
          @cultivation_plan_gateway = cultivation_plan_gateway
          @logger = logger
          @translator = translator
          @clock = clock
          @session_id_generator = session_id_generator
          @job_chain_enqueuer = job_chain_enqueuer
        end

        def call(input_dto)
          unless Domain::Shared.present?(input_dto.crop_ids)
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :unprocessable_entity,
                message: @translator.t("plans.errors.select_crop")
              )
            )
            return
          end

          farm = @cultivation_plan_gateway.find_by_farm_id(input_dto.farm_id, input_dto.user)
          unless farm
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :not_found,
                message: @translator.t("plans.errors.not_found")
              )
            )
            return
          end

          crops = @cultivation_plan_gateway.list_by_ids(input_dto.crop_ids, input_dto.user)
          if crops.empty?
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :not_found,
                message: @translator.t("plans.errors.not_found")
              )
            )
            return
          end

          existing = @cultivation_plan_gateway.find_existing(farm, input_dto.user)
          if existing
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :unprocessable_entity,
                message: @translator.t("plans.errors.plan_already_exists_annual")
              )
            )
            return
          end

          plan_name = input_dto.plan_name || farm.name
          session_id = @session_id_generator.call
          total_area = @cultivation_plan_gateway.total_field_area_for_farm(farm.id, input_dto.user)

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
            @logger.error("❌ [PrivatePlanInitializeFromSelectionInteractor] Initialize failed: #{msg}")
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :unprocessable_entity,
                message: msg
              )
            )
            return
          end

          plan_id = result.cultivation_plan.id
          @logger.info("✅ [PrivatePlanInitializeFromSelectionInteractor] CultivationPlan created: #{plan_id}")

          @job_chain_enqueuer.enqueue_after_create(cultivation_plan_id: plan_id)

          @output_port.on_success(Dtos::PrivatePlanInitializeFromSelectionOutput.new(id: plan_id))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.error("❌ [PrivatePlanInitializeFromSelectionInteractor] #{e.class}: #{e.message}")
          @output_port.on_failure(
            Dtos::PrivatePlanInitializeFromSelectionFailure.new(
              http_status: :unprocessable_entity,
              message: e.message
            )
          )
        end
      end
    end
  end
end
