# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmDeletePresenter < Domain::Farm::Ports::FarmDestroyOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(destroy_output_dto)
          # 成功データをコントローラーに渡す
          @view.instance_variable_set('@farm_delete_data', destroy_output_dto)
        end

        def on_failure(error_dto)
          # エラーデータをコントローラーに渡す
          @view.instance_variable_set('@farm_delete_error', error_dto)
        end

        private

        def resource_dom_id_for(event)
          stored = event.metadata['resource_dom_id']
          return stored if stored.present?

          [event.resource_type.demodulize.underscore, event.resource_id].join('_')
        end
      end
    end
  end
end
