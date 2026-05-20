# frozen_string_literal: true

# ドメイン interactor に注入する翻訳ポートのテスト用実装（I18n に委譲）。
module DomainLibTestSupport
  class I18nForwardingTranslator
    def t(key, **options)
      I18n.t(key, **options)
    end

    def l(value, **options)
      I18n.l(value, **options)
    end
  end
end
