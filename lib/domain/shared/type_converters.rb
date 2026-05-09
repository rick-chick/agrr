# frozen_string_literal: true

module Domain
  module Shared
    module TypeConverters
      # ActiveModel::Type::BooleanのRails非依存代替実装
      # 既存のActiveModel::Type::Boolean.new.cast()と同じ振る舞いを維持
      class BooleanConverter
        TRUTHY_VALUES = [ true, "true", "1", 1, "yes", "on", "t", "y" ].freeze
        FALSY_VALUES = [ false, "false", "0", 0, "no", "off", "f", "n", nil, "" ].freeze

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

      # agrr 等の外部数値（文字列・欠損）を整数に正規化する（Rails 非依存）
      class IntegerConverter
        def self.cast(value)
          return value if value.is_a?(Integer)
          return nil if value.nil?

          str = value.to_s
          return nil unless str.match?(/\A-?\d+\z/)

          str.to_i
        end
      end

      # agrr 等の外部数値を BigDecimal に正規化する（Rails 非依存）
      class BigDecimalConverter
        def self.cast(value)
          return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)
          return value if value.is_a?(BigDecimal)

          BigDecimal(value.to_s)
        end
      end
    end
  end
end
