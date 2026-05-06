# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class MastersCropPestsDestroyInteractor
        def initialize(output_port:, user_id:, user_lookup:, pest_gateway:)
          @output_port = output_port
          @user_id = user_id
          @user_lookup = user_lookup
          @pest_gateway = pest_gateway
        end

        def call(crop_id:, pest_id:)
          user = @user_lookup.find(@user_id)
          status = @pest_gateway.unlink_pest_from_crop_for_masters(
            user: user,
            crop_id: crop_id.to_i,
            pest_id: pest_id.to_i
          )

          case status
          when :ok
            @output_port.on_success
          when :crop_not_found
            @output_port.on_crop_not_found
          when :pest_not_found
            @output_port.on_pest_not_found
          when :not_associated
            @output_port.on_not_associated
          else
            @output_port.on_unexpected(status)
          end
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_crop_not_found
        end
      end
    end
  end
end
