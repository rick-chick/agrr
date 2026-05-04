# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      # 作物の作業テンプレートトグル（永続化＋表示用スナップショット）。
      # 具象アダプタは内部で ActiveRecord を用いて読み込み・更新する。
      class CropTaskTemplateToggleGateway
        def toggle_build_snapshot!(crop:, agricultural_task:)
          raise NotImplementedError, "#{self.class} must implement #toggle_build_snapshot!"
        end
      end
    end
  end
end
