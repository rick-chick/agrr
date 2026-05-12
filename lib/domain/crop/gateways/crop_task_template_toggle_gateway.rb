# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      # 作物の作業テンプレートトグル（永続化＋表示用スナップショット）。
      # @param crop_id [Integer]
      # @param agricultural_task_id [Integer]
      class CropTaskTemplateToggleGateway
        def toggle_build_snapshot!(crop_id:, agricultural_task_id:)
          raise NotImplementedError, "#{self.class} must implement #toggle_build_snapshot!"
        end
      end
    end
  end
end
