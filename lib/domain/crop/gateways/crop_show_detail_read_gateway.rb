# frozen_string_literal: true

module Domain
  module Crop
    module Gateways
      # Master crop show: narrow read（snapshot。Entity 組立は Interactor + domain mapper）。
      class CropShowDetailReadGateway
        # @return [Object] Dtos::CropShowDetailSnapshot
        def find_show_detail_snapshot(crop_id:)
          raise NotImplementedError, "Subclasses must implement find_show_detail_snapshot"
        end
      end
    end
  end
end
