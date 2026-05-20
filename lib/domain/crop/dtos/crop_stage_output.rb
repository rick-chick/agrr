# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageOutput
        attr_reader :stage

        def initialize(stage:)
          @stage = stage
        end
      end
    end
  end
end
