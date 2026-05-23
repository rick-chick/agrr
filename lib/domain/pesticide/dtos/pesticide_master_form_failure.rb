# frozen_string_literal: true

module Domain
  module Pesticide
    module Dtos
      # 農薬マスタ HTML の検証失敗時（Interactor がゲートウェイで組み立てた束を渡す）。
      class PesticideHtmlMasterFormFailure
        attr_reader :message, :bundle

        # @param bundle [Domain::Pesticide::Dtos::PesticideHtmlMasterFormBundle]
        def initialize(message:, bundle:)
          @message = message
          @bundle = bundle
        end
      end
    end
  end
end
