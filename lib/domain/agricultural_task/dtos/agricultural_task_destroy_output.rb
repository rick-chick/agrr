# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskDestroyOutput
        attr_reader :undo

        def initialize(undo:)
          @undo = undo
        end
      end
    end
  end
end
