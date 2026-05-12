# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # Gateway が一度読み込んだ農薬について、PesticideEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedPesticideLoadedDto
        attr_reader :pesticide_entity, :master_form_snapshot

        def initialize(pesticide_entity:, master_form_snapshot:)
          @pesticide_entity = pesticide_entity
          @master_form_snapshot = master_form_snapshot
        end
      end
    end
  end
end
