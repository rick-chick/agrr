# frozen_string_literal: true

module Domain
  module Field
    module Results
      # 農場に紐づく圃場一覧ユースケースの戻り（表現形式に依存しない）。
      class FarmFieldsList
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
