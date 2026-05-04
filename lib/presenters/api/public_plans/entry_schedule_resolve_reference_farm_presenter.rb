# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      class EntryScheduleResolveReferenceFarmPresenter
        include EntryScheduleApiFailureRendering

        def initialize(view:)
          @view = view
        end

        def on_success(farm)
          @view.instance_variable_set(:@entry_schedule_reference_farm, farm)
        end

        def on_failure(failure_dto)
          render_entry_schedule_failure(failure_dto)
        end
      end
    end
  end
end
