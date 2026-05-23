# frozen_string_literal: true

module Adapters
  module Shared
    module Presenters
      module ViewModels
        # ReferencableListRow DTO を ERB 向けにそのまま露出する薄い ViewModel。
        class ReferencableListRowViewModel
          attr_reader :record, :display

          def initialize(row_dto:)
            @record = row_dto.record
            @display = row_dto.display
          end
        end
      end
    end
  end
end
