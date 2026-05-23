# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # HTML 害虫マスタの作物選択 UI（選択 ID・カード行）をゲートウェイが組み立てた結果。
      class PestMasterFormCropSelectionBundle
        attr_reader :selected_crop_ids, :crop_cards

        # @param selected_crop_ids [Array<Integer>]
        # @param crop_cards [Array<Hash>] { crop: Domain::Crop::Entities::CropEntity, selected: Boolean }
        def initialize(selected_crop_ids:, crop_cards:)
          @selected_crop_ids = selected_crop_ids
          @crop_cards = crop_cards
        end
      end
    end
  end
end
