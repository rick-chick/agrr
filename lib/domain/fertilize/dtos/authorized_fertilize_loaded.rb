# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # Gateway が一度読み込んだ肥料について、FertilizeEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedFertilizeLoaded
        attr_reader :fertilize_entity, :master_form_snapshot, :html_display

        def initialize(fertilize_entity:, master_form_snapshot:, html_display: nil)
          @fertilize_entity = fertilize_entity
          @master_form_snapshot = master_form_snapshot
          @html_display = html_display
        end

        # HTML 表示用 DTO（Entity 漏れ防止）
        def display_dto
          Domain::Fertilize::Dtos::FertilizeDisplay.new(fertilize_entity: @fertilize_entity)
        end
      end
    end
  end
end
