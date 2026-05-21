# frozen_string_literal: true

# Domain::Shared — ActiveSupport 非依存の純粋ヘルパ（blank? / present? / キー変換等）。
#
# ActiveSupport が無い実行環境（Rails-free な domain-lib テストハーネス）向けに、
# 主要コアクラスへ blank? / present? を後付けする。Rails アプリでは ActiveSupport が
# 同名メソッドを（より厳密に・より広い対象に）提供するため、ここで再定義すると
# ActiveSupport 実装を破壊する（例: String#underscore の :: → / 変換が失われ
# controller_path が壊れる）。よって `unless defined?(ActiveSupport)` でガードし、
# ActiveSupport が居る環境では一切手を加えない。
# Zeitwerk はファイルを module Domain { ... } で囲むため、::String 等で明示的にトップレベルを指定する。
unless defined?(ActiveSupport)
  class ::String
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::Array
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::Hash
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::NilClass
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::FalseClass
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::TrueClass
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end

  class ::Integer
    def blank?
      Domain::Shared.blank?(self)
    end

    def present?
      Domain::Shared.present?(self)
    end
  end
end

module Domain
  module Shared
    # ActiveSupport の Hash#symbolize_keys / stringify_keys / deep_symbolize_keys / blank? / present? の Rails 非依存代替。
    module_function

    # blank? / present?
    def blank?(value)
      case value
      when nil, false
        true
      when true
        false
      when String
        value.strip.empty?
      when Array, Hash
        value.empty?
      else
        false
      end
    end

    def present?(value)
      !blank?(value)
    end

    # Array() の Rails 非依存代替
    def to_array(value)
      case value
      when nil
        []
      when Array
        value
      else
        [value]
      end
    end

    # Hash key conversion
    def stringify_keys(hash)
      return {} if hash.nil?

      hash.to_hash.each_with_object({}) do |(k, v), result|
        result[k.to_s] = v
      end
    end

    def symbolize_keys(hash)
      return {} if hash.nil?

      hash.to_hash.each_with_object({}) do |(k, v), result|
        key = k.respond_to?(:to_sym) ? k.to_sym : k
        result[key] = v
      end
    end

    def deep_symbolize_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) do |(k, v), result|
          key = k.respond_to?(:to_sym) ? k.to_sym : k
          result[key] = deep_symbolize_keys(v)
        end
      when Array
        obj.map { |e| deep_symbolize_keys(e) }
      else
        obj
      end
    end
  end
end
