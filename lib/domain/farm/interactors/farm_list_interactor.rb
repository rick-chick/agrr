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
          input_dto ||= Domain::Farm::Dtos::FarmListInput.new(is_admin: false)
          @gateway.user_id = @user_id
          farms = if input_dto.is_admin
                    @gateway.list_user_and_reference_farms(user_id: @user_id)
                  else
                    @gateway.list_user_owned_farms(user_id: @user_id)
                  end
          reference_farms = input_dto.is_admin ? @gateway.list_reference_farms : []

          @output_port.on_success(farms, reference_farms: reference_farms)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
