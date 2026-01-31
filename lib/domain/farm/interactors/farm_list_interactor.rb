# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmListInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @gateway.user_id = user_id if @gateway.respond_to?(:user_id=)
          @user_id = user_id
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @gateway.user_id = @user_id
          farms = @gateway.list(input_dto)

          @output_port.on_success(farms)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end