# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestControlMethodSnapshot
        attr_reader :method_type, :method_name, :description, :timing_hint

        def initialize(method_type:, method_name:, description:, timing_hint:)
          @method_type = method_type
          @method_name = method_name
          @description = description
          @timing_hint = timing_hint
        end
      end
    end
  end
end
