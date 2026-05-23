# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeDestroyInteractor < Domain::Fertilize::Ports::FertilizeDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(fertilize_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FertilizePolicy.record_access_filter(user)
          current = @gateway.find_by_id(fertilize_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)
          result = @gateway.soft_delete_with_undo(
            user: user,
            fertilize_id: fertilize_id,
            auto_hide_after: 5000,
            translator: @translator
          )
          if result[:success]
            dto = Domain::Fertilize::Dtos::FertilizeDestroyOutput.new(undo: result[:undo_entity])
            @output_port.on_success(dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("fertilizes.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::AssociationInUse
          @output_port.on_failure(
            Domain::Shared::Dtos::Error.new(@translator.t("fertilizes.flash.cannot_delete_in_use"))
          )
        end
      end
    end
  end
end
