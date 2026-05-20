# frozen_string_literal: true

module Adapters
  module Farm
    module Mappers
      # +Farm+ レコードから {Domain::Farm::Dtos::FarmMasterFormSnapshot} を組み立てる。
      class FarmMasterFormSnapshotMapper
        class << self
          # @param farm [::Farm]
          # @param error_messages [Array<String>]
          # @return [Domain::Farm::Dtos::FarmMasterFormSnapshot]
          def from_record(farm, error_messages: [])
            attrs = farm.attributes.symbolize_keys.slice(
              :name, :latitude, :longitude, :region, :is_reference, :user_id
            )
            Domain::Farm::Dtos::FarmMasterFormSnapshot.new(
              attributes: attrs,
              new_record: farm.new_record?,
              id: farm.id,
              error_messages: Array(error_messages)
            )
          end
        end
      end
    end
  end
end
