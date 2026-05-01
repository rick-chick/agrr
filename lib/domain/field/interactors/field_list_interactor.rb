# frozen_string_literal: true

module Domain
  module Field
    module Interactors
      class FieldListInteractor < Domain::Field::Ports::FieldListInputPort
        def initialize(output_port:, user_id:, gateway:, logger:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @gateway.translator = Domain::Shared::Ports::TranslatorPort.default if @gateway.respond_to?(:translator=)
        end

        def call(farm_id)
          fields = @gateway.list_by_farm(farm_id, @user_id)
          @output_port.on_success(fields)
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
