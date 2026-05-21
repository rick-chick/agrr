# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor / domain mapper が I18n を直接参照しないための翻訳ポート（include 用）。
      # 具体実装は Adapters::Shared::Ports::RailsTranslatorAdapter（CompositionRoot で生成し DI）。
      module TranslatorPort
        # 翻訳キーを翻訳する。
        def translate(key, **options)
          raise NotImplementedError, "#{self.class}#translate"
        end

        # translate のエイリアス。
        def t(key, **options)
          translate(key, **options)
        end

        # I18n.l 相当（Date 等の表示整形）。
        def localize(date, format: nil, **options)
          raise NotImplementedError, "#{self.class}#localize"
        end

        # localize のエイリアス。
        def l(date, format: nil, **options)
          localize(date, format: format, **options)
        end
      end
    end
  end
end
