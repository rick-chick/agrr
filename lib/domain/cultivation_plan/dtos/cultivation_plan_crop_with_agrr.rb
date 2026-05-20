# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # optimize 用: CultivationPlanCrop + crop.to_agrr_requirement 相当（Gateway で組み立て）
      class CultivationPlanCropWithAgrr
        attr_reader :id, :name, :crop_id, :agrr_requirement, :revenue_per_area, :crop_name

        def initialize(id:, name:, crop_id:, agrr_requirement:, revenue_per_area:, crop_name:)
          @id = id
          @name = name
          @crop_id = crop_id
          @agrr_requirement = agrr_requirement
          @revenue_per_area = revenue_per_area
          @crop_name = crop_name
        end
      end
    end
  end
end
