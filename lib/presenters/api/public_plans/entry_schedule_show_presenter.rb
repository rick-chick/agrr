# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # entry_schedule show: Interactor 出力 DTO を ETag 付き JSON に載せるのみ
      class EntryScheduleShowPresenter < Domain::PublicPlan::Ports::EntryScheduleShowOutputPort
        include EntryScheduleApiFailureRendering

        def initialize(view:)
          @view = view
        end

        def on_success(success_dto)
          @view.render_entry_json_with_etag(success_dto.to_h)
        end

        def on_failure(failure_dto)
          render_entry_schedule_failure(failure_dto)
        end
      end
    end
  end
end
