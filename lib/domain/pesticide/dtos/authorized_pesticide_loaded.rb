# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # Gateway が一度読み込んだ農薬について、PesticideEntity とフォーム表示用スナップショットを束ねる。
      class AuthorizedPesticideLoaded
        attr_reader :pesticide_entity, :master_form_snapshot, :html_display

        def initialize(pesticide_entity:, master_form_snapshot:, html_display: nil)
          @pesticide_entity = pesticide_entity
          @master_form_snapshot = master_form_snapshot
          @html_display = html_display
        end
      end
    end
  end
end
