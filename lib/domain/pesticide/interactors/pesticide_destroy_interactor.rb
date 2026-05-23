# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDestroyInteractor < Domain::Pesticide::Ports::PesticideDestroyInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          current = @gateway.find_by_id(pesticide_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_edit_allowed!(access_filter, current)
          result = @gateway.soft_delete_with_undo(
            user: user,
            pesticide_id: pesticide_id,
            auto_hide_after: 5000,
            translator: @translator
          )
          if result[:success]
            dto = Domain::Pesticide::Dtos::PesticideDestroyOutput.new(undo: result[:undo_entity])
            @output_port.on_success(dto)
          else
            @output_port.on_failure(result[:error_dto])
          end
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("pesticides.flash.not_found")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
