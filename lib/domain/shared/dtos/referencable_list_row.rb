# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # 一覧行: ドメイン record + HTML 表示フラグ。
      class ReferencableListRow
        attr_reader :record, :display

        def initialize(record:, display:)
          @record = record
          @display = display
        end
      end
    end
  end
end
