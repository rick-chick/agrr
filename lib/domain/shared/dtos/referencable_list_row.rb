# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # 一覧行: ドメイン record のみ（API JSON は entity をそのまま出す）。
      class ReferencableListRow
        attr_reader :record

        def initialize(record:)
          @record = record
        end
      end
    end
  end
end
