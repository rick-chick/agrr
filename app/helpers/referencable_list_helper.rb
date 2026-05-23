# frozen_string_literal: true

module ReferencableListHelper
  ListRowParts = Struct.new(:record, :display, keyword_init: true)

  def referencable_list_row_parts(row)
    if row.is_a?(Adapters::Shared::Presenters::ViewModels::ReferencableListRowViewModel) ||
       row.is_a?(Domain::Shared::Dtos::ReferencableListRow)
      ListRowParts.new(record: row.record, display: row.display)
    else
      ListRowParts.new(record: row, display: nil)
    end
  end
end
