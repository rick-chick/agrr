# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # Policy 正規化後・ゲートウェイ永続化境界に渡す害虫属性（AR 非依存）。
      class PestPersistAttrs
        KEYS = %i[
          name name_scientific family order description occurrence_season region
          is_reference user_id source_pest_id
          pest_temperature_profile_attributes pest_thermal_requirement_attributes pest_control_methods_attributes
        ].freeze

        # @param attributes [Hash] symbolize 済みでも可
        def initialize(attributes)
          raw = Domain::Shared.symbolize_keys(attributes.to_h)
          @attributes = raw.slice(*KEYS).freeze
          freeze
        end

        # @param hash [Hash]
        # @return [Domain::Pest::Dtos::PestPersistAttrs]
        def self.from_normalized_hash(hash)
          new(hash)
        end

        KEYS.each do |key|
          define_method(key) { @attributes[key] }
        end

        # ActiveRecord 代入用コピー（アダプターが変更しても DTO 不変）
        # @return [Hash]
        def to_ar_attributes
          @attributes.dup
        end
      end
    end
  end
end
