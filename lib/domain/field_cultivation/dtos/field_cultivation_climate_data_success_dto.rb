# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Dtos
      class FieldCultivationClimateDataSuccessDto
        attr_reader :field_cultivation, :farm, :crop_requirements,
                    :weather_data, :gdd_data, :stages, :progress_result,
                    :debug_info

        def initialize(field_cultivation:, farm:, crop_requirements:,
                       weather_data:, gdd_data:, stages:,
                       progress_result:, debug_info:)
          @field_cultivation = field_cultivation
          @farm = farm
          @crop_requirements = crop_requirements
          @weather_data = weather_data
          @gdd_data = gdd_data
          @stages = stages
          @progress_result = progress_result
          @debug_info = debug_info
        end
      end
    end
  end
end
