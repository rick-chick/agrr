# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Errors
      # 最適化時に計画に紐づく CultivationPlanCrop が欠落している（データ不整合）。
      class CultivationPlanCropMissingError < StandardError; end
    end
  end
end
