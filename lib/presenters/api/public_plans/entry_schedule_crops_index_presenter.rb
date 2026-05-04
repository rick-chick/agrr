# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      class EntryScheduleCropsIndexPresenter < Domain::PublicPlan::Ports::EntryScheduleCropsIndexOutputPort
        include EntryScheduleApiFailureRendering

        def initialize(view:)
          @view = view
        end

        def on_success(payload_hash)
          @view.render_entry_json_with_etag(payload_hash)
        end

        def on_failure(failure_dto)
          render_entry_schedule_failure(failure_dto)
        end
      end
    end
  end
end
