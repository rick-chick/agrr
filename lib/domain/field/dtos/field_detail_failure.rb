# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      # 圃場詳細失敗時に Output Port へ渡す（HTML リダイレクト用 farm_id を含む）。
      class FieldDetailFailure
        attr_reader :message, :farm_id

        # @param message [String]
        # @param farm_id [Integer, nil]
        def initialize(message:, farm_id: nil)
          @message = message
          @farm_id = farm_id
        end
      end
    end
  end
end
