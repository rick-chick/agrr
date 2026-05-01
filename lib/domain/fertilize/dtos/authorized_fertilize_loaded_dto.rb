# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # Gateway が一度読み込んだ肥料について、FertilizeEntity と永続モデルを束ねる。
      class AuthorizedFertilizeLoadedDto
        attr_reader :fertilize_entity, :persisted_fertilize

        def initialize(fertilize_entity:, persisted_fertilize:)
          @fertilize_entity = fertilize_entity
          @persisted_fertilize = persisted_fertilize
        end
      end
    end
  end
end
