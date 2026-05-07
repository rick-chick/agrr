# frozen_string_literal: true

module Domain
  module PublicPlan
    module Dtos
      # HTML 公開プラン作成失敗で、作物ゼロ時に再描画に必要な文脈を運ぶ（API は message のみ使用）。
      class PublicPlanCreateFailureDto
        KIND_NO_CROPS = :no_crops

        attr_reader :kind, :message, :farm_id, :farm_size_id, :region

        def initialize(kind:, message:, farm_id: nil, farm_size_id: nil, region: nil)
          @kind = kind
          @message = message
          @farm_id = farm_id
          @farm_size_id = farm_size_id
          @region = region
        end

        def no_crops?
          kind == KIND_NO_CROPS
        end
      end
    end
  end
end
