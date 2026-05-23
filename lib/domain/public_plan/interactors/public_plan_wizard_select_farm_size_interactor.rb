# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      class PublicPlanWizardSelectFarmSizeInteractor
        def initialize(public_plan_gateway:, output_port:)
          @public_plan_gateway = public_plan_gateway
          @output_port = output_port
        end

        def call(farm_id:, alert_i18n_key:)
          farm = @public_plan_gateway.find_by_farm_id(farm_id)
          unless farm
            @output_port.on_missing_farm(alert_i18n_key: alert_i18n_key)
            return
          end

          farm_sizes = @public_plan_gateway.list_farm_sizes
          dto = Domain::PublicPlan::Dtos::PublicPlanWizardSelectFarmSizeOutput.new(
            farm: farm,
            farm_sizes: farm_sizes,
            session_patch: { farm_id: farm.id }
          )
          @output_port.on_success(dto)
        end
      end
    end
  end
end
