# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # Gateway が一度読み込んだ農作業について、AgriculturalTaskEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedAgriculturalTaskLoaded
        attr_reader :agricultural_task_entity, :master_form_snapshot

        def initialize(agricultural_task_entity:, master_form_snapshot:)
          @agricultural_task_entity = agricultural_task_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
