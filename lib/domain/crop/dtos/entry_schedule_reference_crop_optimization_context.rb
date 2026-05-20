# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # エントリスケジュール API 用: 参照作物の最適化計算に必要な純データ（Gateway アダプター内で AR から組み立て、ユースケース境界では AR を渡さない）
      class EntryScheduleReferenceCropOptimizationContext
        attr_reader :id, :name, :variety

        # @param agrr_requirement_hash [Hash] Crop#to_agrr_requirement 相当（文字列キー想定）
        def initialize(id:, name:, variety:, agrr_requirement_hash:)
          @id = id
          @name = name
          @variety = variety
          @agrr_requirement_hash = agrr_requirement_hash
        end

        # Agrr 最適化ゲートウェイと同一ダックタイプ（ActiveRecord::Crop と置換）
        def to_agrr_requirement
          @agrr_requirement_hash
        end
      end
    end
  end
end
