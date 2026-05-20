# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # 圃場マスタ HTML 用スナップショット（AR をビューに渡さない）。
      class FieldMasterFormSnapshot
        attr_reader :attributes, :new_record, :id, :error_messages

        # @param attributes [#to_hash]
        # @param new_record [Boolean]
        # @param id [Integer, nil]
        # @param error_messages [Array<String>]
        def initialize(attributes:, new_record:, id: nil, error_messages: [])
          @attributes = Domain::Shared.symbolize_keys(attributes.to_hash)
          @new_record = new_record
          @id = id
          @error_messages = Array(error_messages)
        end

        # @return [Boolean] 未保存行としてフォームに載せるとき真
        def new_record?
          @new_record
        end

        # @return [Boolean] 永続化済みか（id ありかつ非 new_record）
        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end
      end
    end
  end
end
