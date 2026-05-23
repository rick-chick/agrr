# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanCreateNoCropsFailureInteractor
        def initialize(output_port:, public_plan_gateway:, crop_gateway:, logger:)
          @output_port = output_port
          @public_plan_gateway = public_plan_gateway
          @crop_gateway = crop_gateway
          @logger = logger
        end

        def call(input)
          farm = @public_plan_gateway.find_farm(input.farm_id)
          unless farm
            @output_port.on_restart_required
            return
          end

          farm_size = input.farm_sizes.find { |fs| fs[:id].to_s == input.farm_size_id.to_s }
          unless farm_size
            @output_port.on_restart_required
            return
          end

          region_effective = input.region.presence || farm.region
          crops = begin
            @crop_gateway.list_reference_crop_entities(region: region_effective)
          rescue Domain::Shared::Exceptions::RecordInvalid => e
            @logger.warn("[PublicPlanCreateNoCropsFailureInteractor] #{e.message}")
            []
          end

          @output_port.on_render_select_crop_no_crops_failure(farm: farm, farm_size: farm_size, crops: crops)
        end
      end
    end
  end
end
