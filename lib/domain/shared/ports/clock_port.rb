# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor / Gateway が Date.current を直接参照しないための日付ポート。
      # Rails 向け具体実装は Adapters::Shared::Ports::RailsClockAdapter。
      # Controller / CompositionRoot / Job で Adapter を生成しインスタンスへ DI する。
      module ClockPort
        def today
          raise NotImplementedError, "#{self.class}#today"
        end
      end
    end
  end
end
