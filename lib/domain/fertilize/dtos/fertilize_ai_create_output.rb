# frozen_string_literal: true

module Domain
  module Fertilize
    module Dtos
      class FertilizeAiCreateOutput
        attr_reader :http_status, :success, :fertilize_id, :fertilize_name, :n, :p, :k,
                    :description, :package_size, :message

        def initialize(
          http_status:,
          fertilize_id:,
          fertilize_name:,
          n:,
          p:,
          k:,
          description:,
          package_size:,
          message:
        )
          @http_status = http_status
          @success = true
          @fertilize_id = fertilize_id
          @fertilize_name = fertilize_name
          @n = n
          @p = p
          @k = k
          @description = description
          @package_size = package_size
          @message = message
        end
      end
    end
  end
end
