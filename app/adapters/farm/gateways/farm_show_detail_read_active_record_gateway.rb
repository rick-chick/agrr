# frozen_string_literal: true

module Adapters
  module Farm
    module Gateways
      class FarmShowDetailReadActiveRecordGateway < Domain::Farm::Gateways::FarmShowDetailReadGateway
        def find_show_detail_snapshot(farm_id:)
          farm = ::Farm.includes(:fields).find(farm_id)
          Mappers::FarmShowDetailSnapshotMapper.from_model(farm)
        rescue ActiveRecord::RecordNotFound => e
          raise Domain::Shared::Exceptions::RecordNotFound, e.message
        end
      end
    end
  end
end
