# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListInteractor < Domain::Crop::Ports::CropListInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          crops = @gateway.list_index_for_user(user)
          @output_port.on_success(crops)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
