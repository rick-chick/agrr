# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が Rails.logger を直接参照しないためのインクルード用ポート（メソッド契約）。
      # 完全な契約の参照先は Domain::Shared::Ports::LoggerPort（debug〜unknown）。
      # Rails 向け具体実装は Adapters::Shared::Ports::RailsLoggerAdapter。
      # Controller / CompositionRoot で Adapter を生成しインスタンスへ DI する。
      # このモジュールは Interactor 側がよく使う #info / #warn / #error / #debug のみを列挙している。
      # include 必須ではなく、呼び出しが触るメソッドを備えたダックタイプのインスタンスでもよい。
      module LoggerPort
        def info(message)
          raise NotImplementedError, "#{self.class}#info"
        end

        def warn(message)
          raise NotImplementedError, "#{self.class}#warn"
        end

        def error(message)
          raise NotImplementedError, "#{self.class}#error"
        end

        def debug(message)
          raise NotImplementedError, "#{self.class}#debug"
        end
      end
    end
  end
end
