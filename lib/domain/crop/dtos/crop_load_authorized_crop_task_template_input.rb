# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropLoadAuthorizedCropTaskTemplateInput
        attr_reader :crop_id, :template_id

        def initialize(crop_id:, template_id:)
          @crop_id = crop_id
          @template_id = template_id
        end
      end
    end
  end
end
