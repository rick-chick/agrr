# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      # Pest に紐づく crop 関連を差分同期する（認可済み crop_ids のみ渡すこと）。
      class PestUpdateCropAssociationsInteractor
        def initialize(crop_pest_gateway:)
          @sync = Services::CropPestAssociationSync.new(crop_pest_gateway: crop_pest_gateway)
        end

        # @param crop_ids [Array<Integer>]
        # @return [Domain::Pest::Dtos::PestCropAssociationSyncResult]
        def call(pest_id:, crop_ids:)
          @sync.replace_all(pest_id: pest_id, crop_ids: crop_ids)
        end
      end
    end
  end
end
