# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Presenters
      module Api
        class PrivateOwnedPlansListPresenter
          def initialize(view:, translator:)
            @view = view
            @translator = translator
          end

          def on_success(rows)
            payload = rows.map do |row|
              {
                id: row.id,
                name: row.display_name,
                status: row.status
              }
            end
            @view.render json: payload
          end

          def on_failure(error_dto)
            @view.render json: { error: error_dto.message }, status: :unprocessable_entity
          end
        end
      end
    end
  end
end
