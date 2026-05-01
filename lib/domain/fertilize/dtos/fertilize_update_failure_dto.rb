# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料更新失敗時に Output Port へ渡す。HTML 再表示用の reload_bundle は任意。
      class FertilizeUpdateFailureDto
        attr_reader :message, :reload_bundle

        # @param message [String]
        # @param reload_bundle [Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto, nil]
        def initialize(message:, reload_bundle: nil)
          @message = message
          @reload_bundle = reload_bundle
        end
      end
    end
  end
end
