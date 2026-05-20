# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      # +Field+ レコードから {Domain::Farm::Dtos::FieldMasterFormSnapshot} を組み立てる。
      class FieldMasterFormSnapshotMapper
        class << self
          # @param field [::Field]
          # @param error_messages [Array<String>]
          # @return [Domain::Farm::Dtos::FieldMasterFormSnapshot]
          def from_record(field, error_messages: [])
            attrs = field.attributes.symbolize_keys.slice(
              :name, :area, :daily_fixed_cost, :region, :farm_id, :user_id
            )
            Domain::Farm::Dtos::FieldMasterFormSnapshot.new(
              attributes: attrs,
              new_record: field.new_record?,
              id: field.id,
              error_messages: Array(error_messages)
            )
          end
        end
      end
    end
  end
end
