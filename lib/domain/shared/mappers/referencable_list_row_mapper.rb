# frozen_string_literal: true

module Domain
  module Shared
    module Mappers
      module ReferencableListRowMapper
        module_function

        def map_records(user, records)
          records.map { |record| map_record(user, record) }
        end

        def map_record(user, record)
          is_reference = record.respond_to?(:reference?) ? record.reference? : !!record.is_reference
          Domain::Shared::Dtos::ReferencableListRow.new(
            record: record,
            display: Domain::Shared::Dtos::ResourceDisplayCapabilities.for_list_row(
              user,
              is_reference: is_reference,
              user_id: record.user_id
            )
          )
        end
      end
    end
  end
end
