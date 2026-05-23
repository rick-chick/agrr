# frozen_string_literal: true

module Adapters
  module Shared
    module Presenters
      # ReferencableListRow を API JSON 化するときに entity を取り出す。
      module ListRowSupport
        def unwrap_list_record(item)
          item.is_a?(Domain::Shared::Dtos::ReferencableListRow) ? item.record : item
        end
      end
    end
  end
end
