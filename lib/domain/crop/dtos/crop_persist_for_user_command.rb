# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # 作物永続化（create/update）の属性束ね。Hash をゲートウェイ公開シグネチャから直接渡さない。
      class CropPersistForUserCommand
        attr_reader :attributes

        def initialize(attributes)
          h = attributes.respond_to?(:to_h) ? attributes.to_h : attributes
          @attributes = h.stringify_keys.freeze
        end
      end
    end
  end
end
