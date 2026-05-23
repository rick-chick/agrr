# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanWizardSelectCropInteractor
        def initialize(public_plan_gateway:, crop_gateway:, output_port:, logger:)
          @public_plan_gateway = public_plan_gateway
          @crop_gateway = crop_gateway
          @output_port = output_port
          @logger = logger
        end

        def call(farm_id:, farm_size_id:)
          if farm_id.blank?
            @output_port.on_missing_session
            return
          end

          farm = @public_plan_gateway.find_by_farm_id(farm_id)
          unless farm
            @output_port.on_missing_farm
            return
          end

          farm_size = @public_plan_gateway.find_by_farm_size_id(farm_size_id)
          allowed_ids = Domain::PublicPlan::Catalog::FarmSizeCatalog::ALLOWED_IDS
          unless farm_size && allowed_ids.include?(farm_size[:id].to_s)
            @output_port.on_invalid_farm_size(farm_id: farm.id)
            return
          end

          crops = @crop_gateway.list_reference_crop_entities(region: farm.region)
          session_patch = {
            total_area: farm_size[:area_sqm],
            farm_size_id: farm_size[:id]
          }

          dto = Domain::PublicPlan::Dtos::PublicPlanWizardSelectCropOutput.new(
            farm: farm,
            farm_size: farm_size,
            crops: crops,
            session_patch: session_patch
          )
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @logger.warn "❌ [PublicPlanWizardSelectCropInteractor] #{e.message}"
          @output_port.on_missing_farm
        end
      end
    end
  end
end
