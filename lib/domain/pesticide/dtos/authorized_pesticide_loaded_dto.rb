# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # Gateway が一度読み込んだ農薬について、PesticideEntity と永続モデルを束ねる。
      class AuthorizedPesticideLoadedDto
        attr_reader :pesticide_entity, :persisted_pesticide

        def initialize(pesticide_entity:, persisted_pesticide:)
          @pesticide_entity = pesticide_entity
          @persisted_pesticide = persisted_pesticide
        end
      end
    end
  end
end
