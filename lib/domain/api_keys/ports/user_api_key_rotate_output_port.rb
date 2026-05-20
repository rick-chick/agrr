# frozen_string_literal: true

module Domain
  module ApiKeys
    module Ports
      # ユーザー API キー再生成・ローテーションの出力ポート。
      module UserApiKeyRotateOutputPort
        # @param api_key [String]
        def on_success(api_key:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end

        # @param message [String]
        def on_failure(message:)
          raise NotImplementedError, "#{self.class}##{__method__}"
        end
      end
    end
  end
end
