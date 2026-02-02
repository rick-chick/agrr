# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropStageListOutputDto
        attr_reader :stages

        def initialize(stages:)
          @stages = stages
        end

        def self.from_hash(hash)
          new(
            stages: hash[:stages] || []
          )
        end
      end
    end
  end
end