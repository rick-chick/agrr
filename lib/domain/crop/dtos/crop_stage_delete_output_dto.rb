# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageDeleteOutputDto
        attr_reader :success

        def initialize(success:)
          @success = success
        end
      end
    end
  end
end