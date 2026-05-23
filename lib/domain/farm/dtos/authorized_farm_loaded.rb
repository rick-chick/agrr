# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # Gateway が一度読み込んだ農場について、FarmEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedFarmLoaded
        attr_reader :farm_entity, :master_form_snapshot, :html_display

        def initialize(farm_entity:, master_form_snapshot:, html_display: nil)
          @farm_entity = farm_entity
          @master_form_snapshot = master_form_snapshot
          @html_display = html_display
        end
      end
    end
  end
end
