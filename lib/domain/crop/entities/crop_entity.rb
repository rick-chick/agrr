# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropEntity
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit, :revenue_per_area, :region, :groups, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @variety = attributes[:variety]
          @is_reference = attributes[:is_reference]
          @area_per_unit = attributes[:area_per_unit]
          @revenue_per_area = attributes[:revenue_per_area]
          @region = attributes[:region]
          @groups = attributes[:groups] || []
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        def display_name
          [name, variety].compact.join(" ")
        end

        # ActiveRecordモデルからの変換
        def self.from_model(crop_model)
          new(
            id: crop_model.id,
            user_id: crop_model.user_id,
            name: crop_model.name,
            variety: crop_model.variety,
            is_reference: crop_model.is_reference,
            area_per_unit: crop_model.area_per_unit,
            revenue_per_area: crop_model.revenue_per_area,
            region: crop_model.region,
            groups: crop_model.groups || [],
            created_at: crop_model.created_at,
            updated_at: crop_model.updated_at
          )
        end

        # ハッシュからの変換（テスト用）
        def self.from_hash(hash)
          new(**hash)
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
        end
      end
    end
  end
end


