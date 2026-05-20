# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropEntity
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit, :revenue_per_area, :region, :groups, :crop_stages, :associated_pests, :created_at, :updated_at

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
          @crop_stages = attributes[:crop_stages] || []
          @associated_pests = attributes[:associated_pests] || []
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        def is_reference?
          reference?
        end

        def to_param
          id.to_s
        end

        def display_name
          [ name, variety ].compact.join(" ")
        end

        # ビュー用 alias: crop.pests で害虫一覧を取得
        def pests
          associated_pests
        end



        def as_json(options = nil)
          {
            id: id,
            user_id: user_id,
            name: name,
            variety: variety,
            is_reference: is_reference,
            area_per_unit: area_per_unit,
            revenue_per_area: revenue_per_area,
            region: region,
            groups: groups,
            associated_pests: associated_pests.map(&:to_hash),
            created_at: created_at,
            updated_at: updated_at
          }
        end

        # ハッシュからの変換（テスト用）
        def self.from_hash(hash)
          new(**hash)
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if Domain::Shared.blank?(name)
        end
      end
    end
  end
end
