# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeDetailOutput
        # Entity 漏れ防止: HTML 表示には DisplayDto を介して渡す
        attr_reader :display_dto, :html_display

        def initialize(fertilize_entity:, html_display: nil)
          @display_dto = Domain::Fertilize::Dtos::FertilizeDisplay.new(fertilize_entity: fertilize_entity)
          @html_display = html_display
        end
      end
    end
  end
end
