# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      class CropShowDetailReadActiveRecordGateway < Domain::Crop::Gateways::CropShowDetailReadGateway
        def find_show_detail_snapshot(crop_id:)
          crop = CropShowDetailPreload.find!(crop_id)
          Mappers::CropShowDetailSnapshotMapper.from_model(crop)
        end
      end
    end
  end
end
