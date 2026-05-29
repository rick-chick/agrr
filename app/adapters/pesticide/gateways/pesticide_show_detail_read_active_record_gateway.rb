# frozen_string_literal: true

module Adapters
  module Pesticide
    module Gateways
      class PesticideShowDetailReadActiveRecordGateway < Domain::Pesticide::Gateways::PesticideShowDetailReadGateway
        def find_show_detail_snapshot(pesticide_id:)
          pesticide = ::Pesticide.includes(
            :crop,
            :pest,
            :pesticide_usage_constraint,
            :pesticide_application_detail
          ).find(pesticide_id)
          Mappers::PesticideShowDetailSnapshotMapper.from_model(pesticide)
        rescue ActiveRecord::RecordNotFound
          raise Domain::Shared::Exceptions::RecordNotFound, "Pesticide not found"
        end
      end
    end
  end
end
