# frozen_string_literal: true

module Adapters
  module PublicPlan
    module Presenters
      module Api
        class EntryScheduleResolveReferenceFarmPresenter
          include EntryScheduleFailureRendering

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
end
