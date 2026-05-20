# frozen_string_literal: true

module Domain
  module Shared
    # Rails form_with / dom_id が参照する model_name の最小代替（ActiveModel::Name 非依存）。
    class FormModelName
      attr_reader :name, :param_key, :route_key, :singular, :plural, :element

      # @param name [String] 論理モデル名（例: "Crop", "CropTaskScheduleBlueprint"）
      def self.from_logical_name(name)
        logical = name.to_s
        pk = snake_case(logical)
        plural = "#{pk}s"
        new(
          name: logical,
          param_key: pk,
          route_key: plural,
          singular: pk,
          element: pk,
          plural: plural
        )
      end

      def initialize(name:, param_key:, route_key: nil, singular: nil, plural: nil, element: nil)
        @name = name.to_s
        @param_key = param_key.to_s
        @route_key = (route_key || param_key).to_s
        @singular = (singular || param_key).to_s
        @element = (element || singular || param_key).to_s
        @plural = plural&.to_s
      end

      def singular_route_key
        @singular
      end

      def plural_route_key
        @plural || "#{@singular}s"
      end

      def human(_locale = nil)
        @human ||= name.to_s.split("::").last.scan(/[A-Z][a-z]+/).join(" ")
      end

      def i18n_key
        param_key.to_sym
      end

      # ActiveSupport::Inflector.underscore と同等の簡易版（ASCII の UpperCamelCase のみ想定）
      def self.snake_case(camel_cased_word)
        camel_cased_word.to_s.split("::").last
          .gsub(/([A-Z]+)([A-Z][a-z])/, "\\1_\\2")
          .gsub(/([a-z\d])([A-Z])/, "\\1_\\2")
          .tr("-", "_")
          .downcase
      end
    end
  end
end
