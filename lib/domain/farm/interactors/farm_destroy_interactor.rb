# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDestroyInteractor < Domain::Farm::Ports::FarmDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(farm_id)
          user = @user_lookup.find(@user_id)
          farm_entity = @gateway.find_authorized_for_edit(user, farm_id)
          toast_message = @translator.t("flash.farms.deleted", name: farm_entity.name)
          result = @gateway.soft_destroy_with_undo(
            user: user,
            farm_id: farm_id,
            auto_hide_after: 5000,
            toast_message: toast_message
          )
          if result[:success]
            destroy_output_dto = Domain::Farm::Dtos::FarmDestroyOutputDto.new(
              undo: result[:undo_entity],
              farm_name: result[:farm_name]
            )
            @output_port.on_success(destroy_output_dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(@translator.t("farms.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::ErrorDto.new(e.message))
        rescue Domain::Shared::Exceptions::AssociationInUse
          @output_port.on_failure(
            Domain::Shared::Dtos::ErrorDto.new(@translator.t("farms.flash.cannot_delete_in_use"))
          )
        end
      end
    end
  end
end
