# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # agrr CLI crop-requirement-file 形式の Hash を組み立てる（I/O なし）。
      # 実装は Adapters::Crop::Ports::CropAgrrRequirementBuilderAdapter。
      module CropAgrrRequirementBuilderPort
        # @param crop_source [Object] ActiveRecord Crop または to_agrr_requirement を持つテストスタブ
        # @return [Hash] 文字列キーの crop requirement
        def build_from(crop_source)
          raise NotImplementedError, "#{self.class}#build_from"
        end
      end
    end
  end
end
