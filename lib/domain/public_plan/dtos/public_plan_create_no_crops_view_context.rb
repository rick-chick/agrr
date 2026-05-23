# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      # 公開プラン作成で作物未選択時、select_crop 再描画に必要な文脈（HTML Presenter は表示整形のみ）。
      class PublicPlanCreateNoCropsViewContext
        attr_reader :farm, :farm_size, :crops

        def initialize(farm:, farm_size:, crops:)
          @farm = farm
          @farm_size = farm_size
          @crops = crops
        end
      end
    end
  end
end
