# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      # 肥料更新失敗時に Output Port へ渡す（リダイレクト先 id のみ。フォーム再描画は行わない）。
      class FertilizeUpdateFailure
        attr_reader :message, :fertilize_id

        # @param message [String]
        # @param fertilize_id [Integer, nil]
        def initialize(message:, fertilize_id: nil)
          @message = message
          @fertilize_id = fertilize_id
        end
      end
    end
  end
end
