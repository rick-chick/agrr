# frozen_string_literal: true

module Domain
  module Shared
    module Ports
      # Interactor が I18n.t を直接参照しないためのポート。
      # 実装は lib/adapters/translators/rails_translator.rb（CompositionRoot で生成して DI）
      module TranslatorPort
        def t(key, **options)
          raise NotImplementedError, "#{self.class}#t"
        end
      end
    end
  end
end
