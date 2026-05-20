# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # プライベート計画ウィザード「作物選択」画面用。ActiveRecord は含めない。
      class PrivatePlanSelectCropContext
        attr_reader :farm, :plan_name, :crops, :total_area

        # @param farm [Domain::Farm::Entities::FarmEntity]
        # @param plan_name [String]
        # @param crops [Array<Domain::Crop::Entities::CropEntity>]
        # @param total_area [#to_f] 圃場面積の合計（㎡）
        def initialize(farm:, plan_name:, crops:, total_area:)
          @farm = farm
          @plan_name = plan_name
          @crops = crops
          @total_area = total_area
        end
      end
    end
  end
end
