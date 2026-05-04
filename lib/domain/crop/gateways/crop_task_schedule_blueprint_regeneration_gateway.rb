# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      # 作物のタスクスケジュールブループリント再生成（AGRR 連携含む）。
      # 具象アダプタは永続の Crop（ActiveRecord）を受け取り、内部で ORM・外部サービスを扱う。
      class CropTaskScheduleBlueprintRegenerationGateway
        def regenerate_from_crop!(crop:)
          raise NotImplementedError, "#{self.class} must implement #regenerate_from_crop!"
        end
      end
    end
  end
end
