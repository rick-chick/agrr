# frozen_string_literal: true

module Domain
  module Field
    module Dtos
      class FieldDestroyOutput
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
