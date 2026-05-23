# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # Turbo Streams 購読タグ用。ERB は streamables のみ参照し AR クラスを知らない。
      # "Farm" は ::Farm.to_param と一致し、従来の turbo_stream_from(Farm, id) と同じ署名ストリーム名になる。
      class TurboStreamSubscription
        FARM_STREAM_CLASS_PARAM = "Farm"

        attr_reader :streamables

        def initialize(streamables:)
          raise ArgumentError, "streamables can't be blank" if Domain::Shared.blank?(streamables)

          @streamables = streamables.freeze
        end

        def ==(other)
          other.is_a?(self.class) && other.streamables == streamables
        end

        def self.for_farm(farm_id)
          new(streamables: [FARM_STREAM_CLASS_PARAM, farm_id])
        end
      end
    end
  end
end
