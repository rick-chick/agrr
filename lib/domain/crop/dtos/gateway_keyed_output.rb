# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # ゲートウェイが Hash で返していた可変キー結果を型付けする薄いラッパー（#[] / #to_h で従来互換）。
      class GatewayKeyedOutput
        def initialize(data)
          @data = data.transform_keys(&:to_sym).freeze
        end

        def [](key)
          @data[key.to_sym]
        end

        def to_h
          @data
        end
      end
    end
  end
end
