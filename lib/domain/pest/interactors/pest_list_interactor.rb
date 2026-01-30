# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestListInteractor < Domain::Pest::Ports::PestListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call
          user = User.find(@user_id)
          visible_scope = Domain::Shared::Policies::PestPolicy.visible_scope(::Pest, user)
          pests = @gateway.list(visible_scope)
          @output_port.on_success(pests)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
