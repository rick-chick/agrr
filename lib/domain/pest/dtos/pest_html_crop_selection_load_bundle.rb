# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # HTML 害虫マスタの作物選択 UI（一覧・選択 ID・カード行）をゲートウェイが組み立てた結果。
      # +accessible_crops+ / +crop_cards+ 内の +crop+ は永続境界（アダプター）の Crop レコード。
      class PestHtmlCropSelectionLoadBundle
        attr_reader :accessible_crops, :selected_crop_ids, :crop_cards

        # @param accessible_crops [Array]
        # @param selected_crop_ids [Array<Integer>]
        # @param crop_cards [Array<Hash>] { crop:, selected: Boolean }
        def initialize(accessible_crops:, selected_crop_ids:, crop_cards:)
          @accessible_crops = accessible_crops
          @selected_crop_ids = selected_crop_ids
          @crop_cards = crop_cards
        end
      end
    end
  end
end
