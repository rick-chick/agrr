# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      # 農場・作物選択から私有計画を初期化し作成（private-plan-create-contract 準拠の分岐）。
      class PrivatePlanInitializeFromSelectionInteractor
        def initialize(
          output_port:,
          cultivation_plan_gateway:,
          farm_gateway:,
          crop_gateway:,
          field_gateway:,
          plan_initializer:,
          logger:,
          translator:,
          clock:,
          session_id_generator:,
          job_chain_enqueuer:
        )
          @output_port = output_port
          @cultivation_plan_gateway = cultivation_plan_gateway
          @farm_gateway = farm_gateway
          @crop_gateway = crop_gateway
          @field_gateway = field_gateway
          @plan_initializer = plan_initializer
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

          farm = resolve_owned_farm(input_dto)
          unless farm
            @output_port.on_failure(
              Dtos::PrivatePlanInitializeFromSelectionFailure.new(
                http_status: :not_found,
                message: @translator.t("plans.errors.not_found")
              )
            )
            return
          end

          crops = resolve_private_plan_crops(input_dto)
          if crops.nil?
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
          total_area = @field_gateway.get_total_area_by_farm_id(farm_id: farm.id)

          result = @plan_initializer.call(
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

        private

        def resolve_owned_farm(input_dto)
          farm = @farm_gateway.find_by_id(input_dto.farm_id)
          unless Domain::Shared::Policies::FarmPolicy.owned_visible?(
            input_dto.user,
            is_reference: farm.is_reference,
            user_id: farm.user_id
          )
            return nil
          end

          farm
        rescue Domain::Shared::Exceptions::RecordNotFound
          nil
        end

        def resolve_private_plan_crops(input_dto)
          requested_ids = Array(input_dto.crop_ids).map(&:to_i).uniq.reject(&:zero?)
          return [] if requested_ids.empty?

          entities = @crop_gateway.list_by_ids(requested_ids)
          accessible = entities.select do |crop|
            Domain::Shared::Policies::CropPolicy.edit_allowed?(
              input_dto.user,
              is_reference: crop.is_reference,
              user_id: crop.user_id
            )
          end
          return nil if accessible.map(&:id).sort != requested_ids.sort

          accessible
        end
      end
    end
  end
end
