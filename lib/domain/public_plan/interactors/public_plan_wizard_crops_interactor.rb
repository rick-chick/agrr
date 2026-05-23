# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanWizardCropsInteractor
        def initialize(output_port:, farm_gateway:, crop_gateway:, logger:)
          @output_port = output_port
          @farm_gateway = farm_gateway
          @crop_gateway = crop_gateway
          @logger = logger
        end

        def call(farm_id:)
          region = @farm_gateway.farm_region_for_wizard_lookup_by_id(farm_id)
          unless region
            @output_port.on_farm_not_found
            return
          end

          crops = @crop_gateway.list_reference_crop_entities(region: region)
          @output_port.on_success(crops)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
