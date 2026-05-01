# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # Gateway が一度読み込んだ農作業について、AgriculturalTaskEntity と永続モデルを束ねる。
      class AuthorizedAgriculturalTaskLoadedDto
        attr_reader :agricultural_task_entity, :persisted_agricultural_task

        def initialize(agricultural_task_entity:, persisted_agricultural_task:)
          @agricultural_task_entity = agricultural_task_entity
          @persisted_agricultural_task = persisted_agricultural_task
        end
      end
    end
  end
end
