# frozen_string_literal: true

module Domain
  module Shared
    module TypeConverters
      # ActiveModel::Type::BooleanのRails非依存代替実装
      # 既存のActiveModel::Type::Boolean.new.cast()と同じ振る舞いを維持
      class BooleanConverter
        TRUTHY_VALUES = [true, 'true', '1', 1, 'yes', 'on', 't', 'y'].freeze
        FALSY_VALUES = [false, 'false', '0', 0, 'no', 'off', 'f', 'n', nil, ''].freeze

        def self.cast(value)
          return false if FALSY_VALUES.include?(value)
          return true if TRUTHY_VALUES.include?(value)

          # 文字列の場合、大文字小文字を無視して判定
          if value.is_a?(String)
            normalized = value.strip.downcase
            return true if TRUTHY_VALUES.include?(normalized)
            return false if FALSY_VALUES.include?(normalized) || normalized.empty?
          end

          # その他の場合、Rubyの真偽値判定を使用
          !!value
        end
      end
    end
  end
end