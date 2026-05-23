# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # 害虫マスタフォームの検証失敗時（Interactor が入力 DTO から組み立てた再描画用データ）。
      class PestMasterFormFailure
        attr_reader :message, :master_edit_payload, :crop_selection_bundle

        # @param master_edit_payload [Domain::Pest::Dtos::PestMasterEditPayload]
        # @param crop_selection_bundle [Domain::Pest::Dtos::PestMasterFormCropSelectionBundle, nil]
        def initialize(message:, master_edit_payload:, crop_selection_bundle: nil)
          @message = message
          @master_edit_payload = master_edit_payload
          @crop_selection_bundle = crop_selection_bundle
        end
      end
    end
  end
end
