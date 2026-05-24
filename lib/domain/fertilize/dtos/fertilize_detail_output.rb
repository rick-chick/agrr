# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeDetailOutput
        # Entity 漏れ防止: Presenter には DisplayDto を介して渡す
        attr_reader :display_dto

        def initialize(fertilize_entity:)
          @display_dto = Domain::Fertilize::Dtos::FertilizeDisplay.new(fertilize_entity: fertilize_entity)
        end
      end
    end
  end
end
