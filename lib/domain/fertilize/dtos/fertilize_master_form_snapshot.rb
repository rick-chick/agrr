# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料マスタ HTML フォーム用の読み取りスナップショット（永続モデルをビューに渡さない）。
      class FertilizeMasterFormSnapshot
        attr_reader :attributes, :new_record, :id, :error_messages

        def initialize(attributes:, new_record:, id: nil, error_messages: [])
          @attributes = Domain::Shared.symbolize_keys(attributes.to_hash)
          @new_record = new_record
          @id = id
          @error_messages = Array(error_messages)
        end

        def new_record?
          @new_record
        end

        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end
      end
    end
  end
end
