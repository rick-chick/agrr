# frozen_string_literal: true

module Adapters
  module Fertilize
    class FertilizeAiGatewayResolver
      def initialize(config_gateway: nil, logger:, translator:)
        @config_gateway = config_gateway
        @logger = logger
        @translator = translator
      end

      def resolve
        @config_gateway || Adapters::Fertilize::Gateways::FertilizeCliGateway.new(
          logger: @logger,
          translator: @translator
        )
      end
    end
  end
end
