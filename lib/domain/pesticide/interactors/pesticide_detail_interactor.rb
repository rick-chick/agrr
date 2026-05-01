# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractor < Domain::Pesticide::Ports::PesticideDetailInputPort
        def initialize(output_port:, user_id:, gateway:, logger:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @logger = logger
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          dto = @gateway.authorized_pesticide_detail_output(user, pesticide_id)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
