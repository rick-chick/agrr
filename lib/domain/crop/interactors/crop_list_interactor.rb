# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropListInteractor < Domain::Crop::Ports::CropListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call
          user = User.find(@user_id)
          visible_scope = Domain::Shared::Policies::CropPolicy.visible_scope(::Crop, user)
          crops = @gateway.list(visible_scope)
          @output_port.on_success(crops)
        rescue ActiveRecord::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
