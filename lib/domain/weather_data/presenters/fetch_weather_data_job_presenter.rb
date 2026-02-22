module Domain
  module WeatherData
    module Presenters
      class FetchWeatherDataJobPresenter
        def info(message)
          raise NotImplementedError
        end

        def warn(message)
          raise NotImplementedError
        end

        def error(message)
          raise NotImplementedError
        end

        def debug(message)
          raise NotImplementedError
        end
      end
    end
  end
end
