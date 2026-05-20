# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      # add_crop REST 経路で作物を一意に指す参照（永続 Crop をコントローラに載せない）。
      class AddCropCropReference
        attr_reader :id

        def initialize(id:)
          @id = id.to_i
        end
      end
    end
  end
end
