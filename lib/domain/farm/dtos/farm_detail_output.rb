# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmDetailOutput
        attr_reader :farm, :fields, :turbo_stream_subscription

        def initialize(farm:, fields:, turbo_stream_subscription: nil)
          @farm = farm
          @fields = fields
          @turbo_stream_subscription = turbo_stream_subscription ||
            Domain::Shared::Dtos::TurboStreamSubscription.for_farm(farm.id)
        end
      end
    end
  end
end
