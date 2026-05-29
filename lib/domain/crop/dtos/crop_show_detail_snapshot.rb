# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailSnapshot
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit,
                    :revenue_per_area, :region, :groups, :created_at, :updated_at,
                    :crop_stages, :pests

        def initialize(id:, user_id:, name:, variety:, is_reference:, area_per_unit:,
                       revenue_per_area:, region:, groups:, created_at:, updated_at:,
                       crop_stages:, pests:)
          @id = id
          @user_id = user_id
          @name = name
          @variety = variety
          @is_reference = is_reference
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @groups = groups
          @created_at = created_at
          @updated_at = updated_at
          @crop_stages = crop_stages
          @pests = pests
          freeze
        end
      end
    end
  end
end
