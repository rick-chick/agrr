# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class AgriculturalTaskSnapshotDto
        attr_reader :id, :name, :description, :is_reference

        def initialize(id:, name:, description:, is_reference:)
          @id = id
          @name = name
          @description = description
          @is_reference = is_reference
        end
      end
    end
  end
end
