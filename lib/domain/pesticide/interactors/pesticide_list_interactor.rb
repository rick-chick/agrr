# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideListInteractor < Domain::Pesticide::Ports::PesticideListInputPort
        def initialize(output_port:, gateway:, user_id:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
        end

        def call
          user = User.find(@user_id)
          pesticides = @gateway.list
          visible_pesticides = Domain::Shared::Policies::PesticidePolicy.visible_scope(::Pesticide, user)
          filtered_pesticides = pesticides.select { |pesticide_entity| visible_pesticides.exists?(pesticide_entity.id) }
          @output_port.on_success(filtered_pesticides)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          raise
        rescue StandardError => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        end
      end
    end
  end
end
