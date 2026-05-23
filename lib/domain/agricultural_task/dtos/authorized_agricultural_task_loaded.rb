# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      # Gateway が一度読み込んだ農作業について、AgriculturalTaskEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedAgriculturalTaskLoaded
        attr_reader :agricultural_task_entity, :master_form_snapshot, :html_display

        def initialize(agricultural_task_entity:, master_form_snapshot:, html_display: nil)
          @agricultural_task_entity = agricultural_task_entity
          @master_form_snapshot = master_form_snapshot
          @html_display = html_display
        end
      end
    end
  end
end
