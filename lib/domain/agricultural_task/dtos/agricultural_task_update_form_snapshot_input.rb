# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Dtos
      class AgriculturalTaskUpdateFormSnapshotInput
        attr_reader :form_resubmit, :accessible_crops

        # @param form_resubmit [Hash, nil] :dto, :task_attributes, :selected_crop_ids
        # @param accessible_crops [Array, nil] Crop AR（作物選択 UI 用）
        def initialize(form_resubmit:, accessible_crops: nil)
          @form_resubmit = form_resubmit
          @accessible_crops = accessible_crops
        end
      end
    end
  end
end
