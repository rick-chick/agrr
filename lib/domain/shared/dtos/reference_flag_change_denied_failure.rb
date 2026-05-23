# frozen_string_literal: true

module Domain
  module Shared
    module Dtos
      # 参照フラグ変更がポリシーで拒否されたときに Output Port へ渡す。
      class ReferenceFlagChangeDeniedFailure
        attr_reader :message, :resource_id

        # @param message [String]
        # @param resource_id [Integer]
        def initialize(message:, resource_id:)
          @message = message
          @resource_id = resource_id
        end
      end
    end
  end
end
