# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskEditFormCropSelectionOutput
        attr_reader :accessible_crops, :accessible_crop_ids, :filtered_selected_crop_ids,
                    :selected_crop_ids_for_form_hidden, :crop_cards

        def initialize(
          accessible_crops:,
          accessible_crop_ids:,
          filtered_selected_crop_ids:,
          selected_crop_ids_for_form_hidden:,
          crop_cards:
        )
          @accessible_crops = accessible_crops
          @accessible_crop_ids = accessible_crop_ids
          @filtered_selected_crop_ids = filtered_selected_crop_ids
          @selected_crop_ids_for_form_hidden = selected_crop_ids_for_form_hidden
          @crop_cards = crop_cards
        end
      end
    end
  end
end
