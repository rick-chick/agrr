# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # Gateway が一度読み込んだ肥料について、FertilizeEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedFertilizeLoadedDto
        attr_reader :fertilize_entity, :master_form_snapshot

        def initialize(fertilize_entity:, master_form_snapshot:)
          @fertilize_entity = fertilize_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
