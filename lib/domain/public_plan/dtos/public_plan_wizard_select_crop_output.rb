# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      class PublicPlanWizardSelectCropOutput
        attr_reader :farm, :farm_size, :crops, :session_patch

        def initialize(farm:, farm_size:, crops:, session_patch:)
          @farm = farm
          @farm_size = farm_size
          @crops = crops
          @session_patch = session_patch
        end
      end
    end
  end
end
