# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropCreateInputDto
        attr_reader :name, :variety, :area_per_unit, :revenue_per_area, :region, :groups, :crop_stages_attributes

        def initialize(name:, variety: nil, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: [], crop_stages_attributes: [])
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @groups = groups || []
          @crop_stages_attributes = crop_stages_attributes || []
        end

        def self.from_hash(hash)
          crop_params = hash[:crop] || hash
          groups = crop_params[:groups]
          # groupsをカンマ区切りテキストから配列に変換
          if groups.is_a?(String)
            groups = groups.split(',').map(&:strip).reject(&:blank?)
          end
          new(
            name: crop_params[:name],
            variety: crop_params[:variety],
            area_per_unit: crop_params[:area_per_unit],
            revenue_per_area: crop_params[:revenue_per_area],
            region: crop_params[:region],
            groups: groups || [],
            crop_stages_attributes: crop_params[:crop_stages_attributes] || []
          )
        end
      end
    end
  end
end
