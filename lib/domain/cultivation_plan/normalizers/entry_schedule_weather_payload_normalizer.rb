# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Normalizers
      # WeatherPredictionInteractor の過去互換: トップの `data` が Hash かつ内側に `data` 配列がある形を
      # フラットな AGRR 気象 JSON に正規化する（正規化しないと日次配列が取れず insufficient_weather になる）。
      class EntryScheduleWeatherPayloadNormalizer
        # @param raw [Hash, nil]
        # @return [Hash] stringify_keys 済み
        def self.call(raw)
          h = raw.is_a?(Hash) ? Domain::Shared.deep_dup(raw) : {}
          h = deep_stringify_keys(h)
          d = h["data"]
          if d.is_a?(Hash) && d["data"].is_a?(Array)
            inner = deep_stringify_keys(d)
            h["data"] = inner["data"]
            %w[latitude longitude elevation timezone].each do |key|
              h[key] = inner[key] if Domain::Shared.blank?(h[key]) && Domain::Shared.present?(inner[key])
            end
          end
          h
        end

        def self.deep_stringify_keys(obj)
          case obj
          when Hash
            obj.each_with_object({}) do |(k, v), result|
              result[k.to_s] = deep_stringify_keys(v)
            end
          when Array
            obj.map { |e| deep_stringify_keys(e) }
          else
            obj
          end
        end

        private_class_method :deep_stringify_keys
      end
    end
  end
end
