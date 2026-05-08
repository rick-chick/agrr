# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Ports
      class ManualPlanAdjustOutputPort
        def on_crop_missing_growth_stages(crop_name:)
          raise NotImplementedError
        end

        # @param result [Hash] adjust_with_db_weather の戻り
        def on_adjust(result:)
          raise NotImplementedError
        end

        def on_not_found
          raise NotImplementedError
        end

        def on_unexpected(message:)
          raise NotImplementedError
        end
      end
    end
  end
end
