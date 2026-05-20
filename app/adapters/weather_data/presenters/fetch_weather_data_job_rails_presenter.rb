module Adapters
  module WeatherData
    module Presenters
      class FetchWeatherDataJobRailsPresenter < Domain::WeatherData::Presenters::FetchWeatherDataJobPresenter
        delegate :info, :warn, :error, :debug, to: :@logger

        def initialize(logger:)
          @logger = logger
        end
      end
    end
  end
end
