# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # Gateway が一度読み込んだ作物について、CropEntity とマスタフォーム用スナップショットを束ねる。
      class AuthorizedCropLoaded
        attr_reader :crop_entity, :master_form_snapshot

        def initialize(crop_entity:, master_form_snapshot:)
          @crop_entity = crop_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
