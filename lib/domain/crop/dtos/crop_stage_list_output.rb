# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageListOutput
        attr_reader :stages

        def initialize(stages:)
          @stages = stages
        end
      end
    end
  end
end
