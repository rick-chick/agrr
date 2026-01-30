# frozen_string_literal: true

module Presenters
  module Html
    module Field
      class FieldCreateHtmlPresenter < Domain::Field::Ports::FieldCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(field_entity)
          farm = @view.instance_variable_get(:@farm)
          @view.redirect_to @view.farm_field_path(farm.id, field_entity.id), notice: I18n.t('fields.flash.created')
        end

        def on_failure(error_dto)
          @view.flash.now[:alert] = error_dto.message
          @view.render_form(:new, status: :unprocessable_entity)
        end
      end
    end
  end
end