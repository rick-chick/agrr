# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物マスタ HTML の検証失敗時（Interactor がゲートウェイで組み立てたスナップショットを渡す）。
      class CropMasterFormFailure
        attr_reader :message, :master_form_snapshot

        # @param message [String]
        # @param master_form_snapshot [Domain::Crop::Dtos::CropMasterFormSnapshot]
        def initialize(message:, master_form_snapshot:)
          @message = message
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
