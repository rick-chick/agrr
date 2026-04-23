# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestListInteractor < Domain::Pest::Ports::PestListInputPort
        def initialize(output_port:, gateway:, user_id:, logger:, translator: nil, user_lookup: Domain::Shared::Ports::UserLookupPort.default)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @translator = translator || Adapters::Translators::RailsTranslator.new
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          visible_scope = @gateway.visible_records(user)
          pests = @gateway.list(visible_scope)
          @output_port.on_success(pests)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
