# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropUpdateInput
        attr_reader :crop_id, :name, :variety, :area_per_unit, :revenue_per_area, :region, :groups, :is_reference, :crop_stages_attributes

        def initialize(crop_id:, name: nil, variety: nil, area_per_unit: nil, revenue_per_area: nil, region: nil, groups: nil, is_reference: nil, crop_stages_attributes: nil)
          @crop_id = crop_id
          @name = name
          @variety = variety
          @area_per_unit = area_per_unit
          @revenue_per_area = revenue_per_area
          @region = region
          @groups = groups
          @is_reference = is_reference
          @crop_stages_attributes = crop_stages_attributes
        end

        def self.from_hash(hash, crop_id)
          crop_params = hash[:crop] || hash
          groups = crop_params[:groups]
          # groupsをカンマ区切りテキストから配列に変換
          if groups.is_a?(String)
            groups = groups.split(",").map(&:strip).reject { |group| Domain::Shared.blank?(group) }
          end
          is_reference = crop_params.key?(:is_reference) ? Domain::Shared::TypeConverters::BooleanConverter.cast(crop_params[:is_reference]) : nil
          new(
            crop_id: crop_id,
            name: crop_params[:name],
            variety: crop_params[:variety],
            area_per_unit: crop_params[:area_per_unit],
            revenue_per_area: crop_params[:revenue_per_area],
            region: crop_params[:region],
            groups: groups,
            is_reference: is_reference,
            crop_stages_attributes: crop_params[:crop_stages_attributes]
          )
        end

        # HTML update 失敗時に {merge_edit_crop_params_for_master_form!} へ渡す属性束（permit 相当）。
        def to_nested_crop_attributes_hash
          h = {
            name: @name,
            variety: @variety,
            area_per_unit: @area_per_unit,
            revenue_per_area: @revenue_per_area,
            region: @region,
            groups: @groups,
            is_reference: @is_reference
          }
          h[:crop_stages_attributes] = @crop_stages_attributes if Domain::Shared.present?(@crop_stages_attributes)
          h
        end
      end
    end
  end
end
