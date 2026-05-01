# frozen_string_literal: true

module Domain
  module WeatherData
    module Ports
      # 気象トレーニング窓・当年履歴・既定予測終了の境界。@clock.today が与えられた「参照日」を唯一の入力にする。
      module WeatherPredictionAnchorsPort
        # @param reference_calendar_day [Date] Interactor が @clock.today でスナップショットした日（アプリ TZ の暦日）
        # @return [Domain::WeatherData::Dtos::WeatherPredictionAnchorsDto]
        def anchors_for(reference_calendar_day)
          raise NotImplementedError, "#{self.class.name}#anchors_for"
        end
      end
    end
  end
end
