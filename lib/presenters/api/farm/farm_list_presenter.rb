# frozen_string_literal: true

module Presenters
  module Api
    module Farm
      class FarmListPresenter < Domain::Farm::Ports::FarmListOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(farms)
          # 成功データをコントローラーに渡す
          @view.instance_variable_set('@farm_list_data', farms)
        end

        def on_failure(error_dto)
          # エラーデータをコントローラーに渡す
          @view.instance_variable_set('@farm_list_error', error_dto)
        end
      end
    end
  end
end
