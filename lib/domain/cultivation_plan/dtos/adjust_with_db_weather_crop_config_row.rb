# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # Agrr crops 配列の 1 要素（requirement JSON 断片をそのまま保持）。
      class AdjustWithDbWeatherCropConfigRow
        # @return [Hash] agrr に渡す作物 requirement ドキュメント（文字列キーを許容）
        attr_reader :agrr_requirement_document

        def initialize(agrr_requirement_document:)
          @agrr_requirement_document = self.class.__send__(:agrr_document_deep_freeze, agrr_requirement_document)
          freeze
        end

        # @param h [Hash]
        # @return [AdjustWithDbWeatherCropConfigRow]
        def self.from_hash(h)
          new(agrr_requirement_document: h.to_hash)
        end

        def self.agrr_document_deep_freeze(doc)
          case doc
          when Hash
            doc.each_with_object({}) { |(k, v), m| m[k] = agrr_document_deep_freeze(v) }.freeze
          when Array
            doc.map { |v| agrr_document_deep_freeze(v) }.freeze
          else
            doc
          end
        end
        private_class_method :agrr_document_deep_freeze

        # agrr 入力はミュータブル前提のため、境界で複製する。
        # @return [Hash]
        def mutable_document_dup
          Marshal.load(Marshal.dump(@agrr_requirement_document))
        end
      end
    end
  end
end
