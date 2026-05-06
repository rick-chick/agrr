# frozen_string_literal: true

module Domain
  module Fertilize
    module Services
      # agrr 肥料 JSON を永続化向け属性に正規化する（API コントローラからの移動）。
      module FertilizeAiAgrrPayloadNormalizer
        module_function

        def normalize_fertilize_payload(info)
          data = info["fertilize"]
          data = json_deep_dup(data) if data.is_a?(Hash)

          unless data
            direct_keys = info.slice("name", "description", "package_size", "n", "p", "k", "npk").compact
            return nil if direct_keys.empty?

            data = direct_keys
            npk_raw = data["npk"]
            if data["n"].nil? && !npk_raw.nil? && !npk_raw.to_s.strip.empty?
              npk_values = parse_npk_string(data.delete("npk"))
              data.merge!(npk_values)
            else
              data.delete("npk")
            end
          end

          data["package_size"] = parse_package_size(data["package_size"])
          data["n"] = normalize_nutrient_value(data["n"])
          data["p"] = normalize_nutrient_value(data["p"])
          data["k"] = normalize_nutrient_value(data["k"])

          data
        end

        def parse_package_size(value)
          return nil if value.nil? || value.to_s.strip.empty?

          numeric_value = value.to_s.gsub(/[^0-9.]/, "").to_f
          numeric_value == 0.0 && !value.to_s.match?(/\d/) ? nil : numeric_value
        end

        def parse_npk_string(value)
          return {} if value.nil? || value.to_s.strip.empty?

          numbers = value.to_s.split(/[-\/\\]/).map { |part| s = part.strip; s.empty? ? nil : s }.compact
          n_value = numbers[0]&.to_f
          p_value = numbers[1]&.to_f
          k_value = numbers[2]&.to_f

          {
            "n" => normalize_nutrient_value(n_value),
            "p" => normalize_nutrient_value(p_value),
            "k" => normalize_nutrient_value(k_value)
          }
        end

        def normalize_nutrient_value(value)
          return nil if value.nil?

          numeric = value.to_f
          numeric.zero? ? nil : numeric
        end

        def json_deep_dup(obj)
          JSON.parse(JSON.generate(obj))
        rescue JSON::GeneratorError, JSON::ParserError
          obj.dup
        end
      end
    end
  end
end
