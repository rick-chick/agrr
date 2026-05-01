# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Interactors
      module EntrySchedule
        CropStageSnapshot = Struct.new(
          :id,
          :name,
          :order,
          :temperature_requirement,
          keyword_init: true
        )
      end
    end
  end
end
