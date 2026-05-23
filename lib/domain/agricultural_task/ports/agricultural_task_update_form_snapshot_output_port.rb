# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Ports
      class AgriculturalTaskUpdateFormSnapshotOutputPort
        def on_apply(task_for_form:, selected_crop_ids:, crop_cards:)
          raise NotImplementedError, "Subclasses must implement on_apply"
        end
      end
    end
  end
end
