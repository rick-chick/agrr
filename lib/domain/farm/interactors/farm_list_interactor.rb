# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmListInteractor < Domain::Farm::Ports::FarmListInputPort
        def initialize(output_port:, user_id:, gateway:, translator:)
          @output_port = output_port
          @gateway = gateway
          @gateway.user_id = user_id if @gateway.respond_to?(:user_id=)
          @user_id = user_id
          @translator = translator
        end

        def call(input_dto = nil)
          input_dto ||= Domain::Farm::Dtos::FarmListInputDto.new(is_admin: false)
          @gateway.user_id = @user_id
          farms = @gateway.list(input_dto)
          reference_farms = @gateway.reference_farms_for_admin_list(is_admin: input_dto.is_admin)

          @output_port.on_success(farms, reference_farms: reference_farms)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
