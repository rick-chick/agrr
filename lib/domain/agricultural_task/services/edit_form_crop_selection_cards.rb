# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Services
      # 農業作業編集フォーム: 作物カード行（作物 + 選択状態）を組み立てる。
      class EditFormCropSelectionCards
        def self.build(accessible_crops:, selected_ids:)
          normalized_ids = Array(selected_ids).map(&:to_i).uniq
          accessible_crops.map do |crop|
            {
              crop: crop,
              selected: normalized_ids.include?(crop.id)
            }
          end
        end
      end
    end
  end
end
