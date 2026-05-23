# frozen_string_literal: true

module Domain
  module PublicPlan
    module Ports
      class PublicPlanCreateNoCropsFailureOutputPort
        def on_restart_required
          raise NotImplementedError, "Subclasses must implement on_restart_required"
        end

        def on_render_select_crop_no_crops_failure(farm:, farm_size:, crops:)
          raise NotImplementedError, "Subclasses must implement on_render_select_crop_no_crops_failure"
        end
      end
    end
  end
end
