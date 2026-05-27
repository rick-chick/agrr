# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Ports
      # CropFind*Interactor の output_port: 解決した作物エンティティを保持する。
      class AddCropCropResolveCollector
        attr_reader :crop_entity

        def on_success(crop)
          @crop_entity = crop
        end

        def on_failure(_error)
          @crop_entity = nil
        end
      end
    end
  end
end
