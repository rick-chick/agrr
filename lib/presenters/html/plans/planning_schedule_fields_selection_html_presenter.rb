# frozen_string_literal: true

module Presenters
  module Html
    module Plans
      class PlanningScheduleFieldsSelectionHtmlPresenter
        def initialize(view:)
          @view = view
        end

        def on_success(dto)
          @view.instance_variable_set(:@farms, dto.farms)
          @view.instance_variable_set(:@selected_farm_id, dto.selected_farm_id)
          @view.instance_variable_set(:@selected_farm, dto.selected_farm)
          @view.instance_variable_set(:@fields, dto.fields)
          @view.instance_variable_set(:@selected_field_ids, dto.selected_field_ids)
          @view.instance_variable_set(:@year_range, dto.year_range)
        end
      end
    end
  end
end
