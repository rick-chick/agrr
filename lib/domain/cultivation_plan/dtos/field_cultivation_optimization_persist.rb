# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # FieldCultivation#optimization_result に保存するスナップショット（agrr allocation 由来）。
      class FieldCultivationOptimizationPersist
        attr_reader :allocation_id, :expected_revenue, :profit, :raw_allocation_document

        # @param allocation_id [Integer]
        # @param expected_revenue [Numeric]
        # @param profit [Numeric]
        # @param raw_allocation_document [Hash] agrr の allocation 行に相当する JSON 互換 Hash
        def initialize(allocation_id:, expected_revenue:, profit:, raw_allocation_document:)
          @allocation_id = allocation_id
          @expected_revenue = expected_revenue
          @profit = profit
          @raw_allocation_document = self.class.__send__(:deep_freeze_document, raw_allocation_document)
          freeze
        end

        # ActiveRecord serialize(JSON) 向けミュータブル Hash
        # @return [Hash]
        def to_storage_hash
          {
            allocation_id: allocation_id,
            expected_revenue: expected_revenue,
            profit: profit,
            raw: Marshal.load(Marshal.dump(raw_allocation_document))
          }
        end

        def self.deep_freeze_document(doc)
          case doc
          when nil then nil
          when Hash then doc.transform_values { |v| deep_freeze_document(v) }.freeze
          when Array then doc.map { |v| deep_freeze_document(v) }.freeze
          else
            doc
          end
        end
        private_class_method :deep_freeze_document
      end
    end
  end
end
