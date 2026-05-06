# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationApiShowInteractor
        def initialize(output_port:, gateway:)
          @output_port = output_port
          @gateway = gateway
        end

        def call(field_cultivation_id:)
          dto = @gateway.fetch_api_summary(field_cultivation_id: field_cultivation_id)
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
