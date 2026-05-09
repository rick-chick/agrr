# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # Pest 更新の失敗時に Output Port へ渡す。HTML 再表示用の reload_bundle は任意。
      class PestUpdateFailureDto
        attr_reader :message, :reload_bundle

        # @param message [String]
        # @param reload_bundle [Domain::Pest::Ports::PestHtmlAuthorizedPestLoad, nil]
        def initialize(message:, reload_bundle: nil)
          @message = message
          @reload_bundle = reload_bundle
        end
      end
    end
  end
end
