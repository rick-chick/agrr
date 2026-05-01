# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # Gateway が一度読み込んだ作物について、CropEntity と永続モデル（連鎖プリロード済み）を束ねる。
      # エッジ（Controller）は +persisted_crop+ を代入し、別クエリでの再取得をしない。
      class AuthorizedCropLoadedDto
        attr_reader :crop_entity, :persisted_crop

        def initialize(crop_entity:, persisted_crop:)
          @crop_entity = crop_entity
          @persisted_crop = persisted_crop
        end
      end
    end
  end
end
