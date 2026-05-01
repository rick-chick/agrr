# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # Gateway が一度読み込んだ害虫について、PestEntity と永続モデルを束ねる。
      class AuthorizedPestLoadedDto
        attr_reader :pest_entity, :persisted_pest

        def initialize(pest_entity:, persisted_pest:)
          @pest_entity = pest_entity
          @persisted_pest = persisted_pest
        end
      end
    end
  end
end
