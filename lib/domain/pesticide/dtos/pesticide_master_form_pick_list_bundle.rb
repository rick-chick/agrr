# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタ HTML の作物・害虫プルダウン行のみ（編集画面の補助読込）。
      class PesticideHtmlPickListBundle
        attr_reader :crop_pick_rows, :pest_pick_rows

        def initialize(crop_pick_rows:, pest_pick_rows:)
          @crop_pick_rows = crop_pick_rows
          @pest_pick_rows = pest_pick_rows
        end
      end
    end
  end
end
