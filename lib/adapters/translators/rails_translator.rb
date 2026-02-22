# frozen_string_literal: true

require 'i18n'

module Adapters
  module Translators
    # RailsのI18nを使用した翻訳アダプター実装
    class RailsTranslator < Domain::Shared::Translators::TranslatorInterface
    # RailsのI18n.t() を使用して翻訳を実行
    # @param key [String, Symbol] 翻訳キー
    # @param options [Hash] 翻訳オプション (default, scopeなど)
    # @return [String] 翻訳された文字列
    def translate(key, **options)
      I18n.t(key, **options)
    end
    end
  end
end