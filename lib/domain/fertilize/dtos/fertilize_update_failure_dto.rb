# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料更新失敗時に Output Port へ渡す。HTML 再表示用のフォームモデルは Interactor が Gateway で解決して渡す（Presenter が controller の ivar を読まない）。
      class FertilizeUpdateFailureDto
        attr_reader :message, :form_fertilize

        # @param message [String]
        # @param form_fertilize [Object, nil] Adapter が読み済みの永続モデルインスタンス（HTML の form_with / errors のみで使用）。
        def initialize(message:, form_fertilize: nil)
          @message = message
          @form_fertilize = form_fertilize
        end
      end
    end
  end
end
