# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が I18n.t を直接参照しないためのポート。
      # 実装は lib/adapters/translators/rails_translator.rb。
      # NOTE: Clean Architecture 純化のため、Controller (Composition Root) で
      # Adapter インスタンスを生成し Interactor へ DI する方式に段階移行中。
      # `.default` は移行未完了の Interactor 互換のため残置（移行完了後に削除）。
      module TranslatorPort
        class << self
          def default
            @default ||= Adapters::Translators::RailsTranslator.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def t(key, **options)
          raise NotImplementedError, "#{self.class}#t"
        end
      end
    end
  end
end
