# frozen_string_literal: true

module Adapters
  module Shared
    module Presenters
      module HtmlDisplaySupport
        def assign_list_row_view_models(view, ivar, rows)
          models = rows.map do |row|
            Adapters::Shared::Presenters::ViewModels::ReferencableListRowViewModel.new(row_dto: row)
          end
          view.instance_variable_set(ivar, models)
        end

        def assign_html_display(view, capabilities)
          view.instance_variable_set(:@html_display, capabilities)
        end

        def assign_new_master_form_html_display(view)
          user = view.send(:current_user)
          assign_html_display(
            view,
            Domain::Shared::Dtos::ResourceDisplayCapabilities.for_referencable_form(
              user,
              crop_is_reference: false,
              crop_user_id: user.id
            )
          )
        end

        def assign_master_form_html_display_for_crop_form(view, crop_form)
          user = view.send(:current_user)
          assign_html_display(
            view,
            Domain::Shared::Dtos::ResourceDisplayCapabilities.for_referencable_form(
              user,
              crop_is_reference: crop_form.is_reference?,
              crop_user_id: crop_form.user_id
            )
          )
        end
      end
    end
  end
end
