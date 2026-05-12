# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      # 作物のタスクスケジュールブループリント再生成（AGRR 連携含む）。
      # @param crop_id [Integer] 再生成対象の作物 ID（AR ロードはアダプタ内で行う）
      class CropTaskScheduleBlueprintRegenerationGateway
        def regenerate_from_crop!(crop_id:)
          raise NotImplementedError, "#{self.class} must implement #regenerate_from_crop!"
        end
      end
    end
  end
end
