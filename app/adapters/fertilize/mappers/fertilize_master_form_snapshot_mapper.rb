# frozen_string_literal: true

module Adapters
  module Fertilize
    module Mappers
      # +Fertilize+ レコードから {Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot} を組み立てる。
      class FertilizeMasterFormSnapshotMapper
        class << self
          # @param fertilize [::Fertilize]
          # @param error_messages [Array<String>]
          # @return [Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot]
          def from_record(fertilize, error_messages: [])
            Domain::Fertilize::Dtos::FertilizeMasterFormSnapshot.new(
              attributes: {
                id: fertilize.id,
                name: fertilize.name,
                n: fertilize.n,
                p: fertilize.p,
                k: fertilize.k,
                description: fertilize.description,
                package_size: fertilize.package_size,
                region: fertilize.region,
                source_fertilize_id: fertilize.source_fertilize_id,
                is_reference: fertilize.is_reference
              },
              new_record: fertilize.new_record?,
              id: fertilize.id,
              error_messages: Array(error_messages)
            )
          end
        end
      end
    end
  end
end
