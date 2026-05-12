# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      # Gateway が一度読み込んだ農場について、FarmEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedFarmLoadedDto
        attr_reader :farm_entity, :master_form_snapshot

        def initialize(farm_entity:, master_form_snapshot:)
          @farm_entity = farm_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
