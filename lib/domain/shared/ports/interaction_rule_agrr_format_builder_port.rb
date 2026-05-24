# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # InteractionRule を agrr 分配用 JSON 配列要素へ変換する（I/O なし）。
      # 実装は Adapters::InteractionRule::Ports::InteractionRuleAgrrFormatBuilderAdapter。
      module InteractionRuleAgrrFormatBuilderPort
        # @param entity_or_record [Domain::InteractionRule::Entities::InteractionRuleEntity, Object]
        # @return [Hash] 文字列キーの agrr ルール 1 件
        def build_from(entity_or_record)
          raise NotImplementedError, "#{self.class}#build_from"
        end

        # @param entities_or_records [Enumerable]
        # @return [Array<Hash>]
        def build_array_from(entities_or_records)
          raise NotImplementedError, "#{self.class}#build_array_from"
        end
      end
    end
  end
end
