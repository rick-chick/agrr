# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物マスタ用の未保存属性スナップショット（`Crop.new` / create 失敗再描画に渡す）。
      class CropMasterBlankFormSnapshot
        attr_reader :attributes

        def initialize(attributes)
          @attributes = attributes.transform_keys(&:to_sym).freeze
        end
      end
    end
  end
end
