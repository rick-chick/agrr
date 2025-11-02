# frozen_string_literal: true

module Domain
  module Pesticide
    module Entities
      # PesticideApplicationDetailsEntity（農薬施用詳細エンティティ）
      #
      # Attributes:
      #   id: データベースの主キー（Integer）
      #   pesticide_id: 農薬ID（Integer、Pesticide.idを参照、ActiveRecordの外部キーと一致）
      #   dilution_ratio: 希釈倍率（例: "1000倍"）
      #   amount_per_m2: 1m²あたりの量
      #   amount_unit: 単位（例: "ml", "g"）
      #   application_method: 施用方法（例: "散布"）
      class PesticideApplicationDetailsEntity
        attr_reader :id, :pesticide_id, :dilution_ratio, :amount_per_m2,
                    :amount_unit, :application_method, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          # pesticide_idは整数ID（Pesticide.id）を指す（ActiveRecordの外部キーと一致）
          @pesticide_id = attributes[:pesticide_id]
          @dilution_ratio = attributes[:dilution_ratio]
          @amount_per_m2 = attributes[:amount_per_m2]
          @amount_unit = attributes[:amount_unit]
          @application_method = attributes[:application_method]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def has_amount?
          amount_per_m2.present? && amount_unit.present?
        end

        private

        def validate!
          # pesticide_idは整数ID（Pesticide.id）を要求
          raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?

          if amount_per_m2
            raise ArgumentError, "Amount per m2 must be positive" if amount_per_m2 < 0
          end

          if amount_unit && !amount_per_m2
            raise ArgumentError, "Amount unit requires amount_per_m2"
          end

          if amount_per_m2 && !amount_unit
            raise ArgumentError, "Amount per m2 requires amount_unit"
          end
        end
      end
    end
  end
end

