# frozen_string_literal: true

module Adapters
  module Fertilize
    class FertilizeAiGatewayResolver
      def initialize(config_gateway: nil)
        @config_gateway = config_gateway
      end

      def resolve
        @config_gateway || Adapters::Fertilize::Gateways::FertilizeCliGateway.new
      end
    end
  end
end
