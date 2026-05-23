# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanWizardSelectFarmSizeOutput
        attr_reader :farm, :farm_sizes, :session_patch

        def initialize(farm:, farm_sizes:, session_patch:)
          @farm = farm
          @farm_sizes = farm_sizes
          @session_patch = session_patch
        end
      end
    end
  end
end
