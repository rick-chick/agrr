# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # Gateway が一度読み込んだ農場について、FarmEntity と永続モデルを束ねる。
      class AuthorizedFarmLoadedDto
        attr_reader :farm_entity, :persisted_farm

        def initialize(farm_entity:, persisted_farm:)
          @farm_entity = farm_entity
          @persisted_farm = persisted_farm
        end
      end
    end
  end
end
