# frozen_string_literal: true

module Domain
  module Shared
    module Mappers
      module ReferencableListRowMapper
        module_function

        def map_records(user, records)
          records.map { |record| map_record(user, record) }
        end

        def map_record(_user, record)
          Domain::Shared::Dtos::ReferencableListRow.new(record: record)
        end
      end
    end
  end
end
