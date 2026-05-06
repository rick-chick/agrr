# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class MastersCropTaskTemplateDestroyInputDto
        attr_reader :user_id, :crop_id, :template_id

        def initialize(user_id:, crop_id:, template_id:)
          @user_id = user_id
          @crop_id = crop_id
          @template_id = template_id
        end
      end
    end
  end
end
