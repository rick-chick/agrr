# frozen_string_literal: true

module Domain
  module Shared
    module Translators
      # 国際化翻訳機能のインターフェース
      # domain層が外部のI18nライブラリに依存しないように抽象化
      class TranslatorInterface
        # 翻訳キーを指定された言語で翻訳する
        # @param key [String, Symbol] 翻訳キー
        # @param options [Hash] 翻訳オプション (default, scopeなど)
        # @return [String] 翻訳された文字列
        def translate(key, **options)
          raise NotImplementedError, "#{self.class}##{__method__} が実装されていません"
        end

        # translate のエイリアスメソッド
        def t(key, **options)
          translate(key, **options)
        end
      end
    end
  end
end