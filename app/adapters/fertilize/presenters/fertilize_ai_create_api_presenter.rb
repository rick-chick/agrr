# frozen_string_literal: true

module Adapters
  module Fertilize
    module Presenters
      class FertilizeAiCreateApiPresenter < Domain::Fertilize::Ports::FertilizeAiCreateOutputPort
        def initialize(view:)
          @view = view
        end

        def on_success(output)
          @view.render_response(
            json: {
              success: output.success,
              fertilize_id: output.fertilize_id,
              fertilize_name: output.fertilize_name,
              n: output.n,
              p: output.p,
              k: output.k,
              description: output.description,
              package_size: output.package_size,
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
