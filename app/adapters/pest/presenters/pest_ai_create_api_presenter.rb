# frozen_string_literal: true

module Adapters
  module Pest
    module Presenters
      class PestAiCreateApiPresenter < Domain::Pest::Ports::PestAiCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output)
          @view.render_response(
            json: {
              success: output.success,
              pest_id: output.pest_id,
              pest_name: output.pest_name,
              name_scientific: output.name_scientific,
              family: output.family,
              order: output.order,
              description: output.description,
              occurrence_season: output.occurrence_season,
              message: output.message
            },
            status: output.http_status
          )
        end

        def on_failure(failure)
          @view.render_response(json: { error: failure.message }, status: failure.http_status)
        end
      end
    end
  end
end
