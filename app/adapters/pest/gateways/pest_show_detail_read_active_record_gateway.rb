# frozen_string_literal: true

module Adapters
  module Pest
    module Gateways
      class PestShowDetailReadActiveRecordGateway < Domain::Pest::Gateways::PestShowDetailReadGateway
        def find_show_detail_snapshot(pest_id:)
          pest = PestShowDetailPreload.find!(pest_id)
          Mappers::PestShowDetailSnapshotMapper.from_model(pest)
        end
      end
    end
  end
end
