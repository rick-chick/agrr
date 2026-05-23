# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # HTML 新規フォーム用（Interactor がゲートウェイで組み立てた状態）。
      # +pest+ はフォーム用の未保存 {::Pest}（アダプター境界で生成）。
      class PestHtmlNewFormState
        attr_reader :pest, :crop_cards, :selected_crop_ids

        # @param pest [::Pest]
        # @param crop_cards [Array<Hash>] { crop:, selected: } 作物選択 UI 用
        # @param selected_crop_ids [Array<Integer>]
        def initialize(pest:, crop_cards:, selected_crop_ids:)
          @pest = pest
          @crop_cards = crop_cards
          @selected_crop_ids = selected_crop_ids
        end
      end
    end
  end
end
