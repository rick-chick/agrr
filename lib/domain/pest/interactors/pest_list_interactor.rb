# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestListInteractor < Domain::Pest::Ports::PestListInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          pests = @gateway.list_index_for_user(user)
          @output_port.on_success(pests)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
