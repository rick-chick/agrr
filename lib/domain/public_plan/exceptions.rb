# frozen_string_literal: true

module Domain
  module PublicPlan
    # 公開エントリスケジュール API 共通（レスキュー経路との互換で Error サフィックスを維持）
    module Exceptions
      WeatherLocationMissingError = Class.new(StandardError)
      PredictionPayloadMissingError = Class.new(StandardError)
      WeatherPredictionFailedError = Class.new(StandardError)
    end
  end
end
