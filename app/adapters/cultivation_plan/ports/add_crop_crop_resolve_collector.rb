# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # CropFind*Interactor の output_port: 解決した作物（Entity / AR）を保持する。
      class AddCropCropResolveCollector
        attr_reader :resolved_crop

        def on_success(crop)
          @resolved_crop = crop
        end

        def on_failure(_error)
          @resolved_crop = nil
        end
      end
    end
  end
end
