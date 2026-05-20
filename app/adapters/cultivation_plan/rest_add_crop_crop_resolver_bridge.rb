# frozen_string_literal: true

module Adapters
  module CultivationPlan
    # add_crop での作物取得（Concern の private をエッジに閉じる）。
    class RestAddCropCropResolverBridge
      def initialize(controller)
        @controller = controller
      end

      def crop_for_add_crop(crop_id)
        @controller.send(:get_crop_for_add_crop, crop_id)
      end
    end
  end
end
