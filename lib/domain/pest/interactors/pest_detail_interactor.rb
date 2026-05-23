# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestDetailInteractor < Domain::Pest::Ports::PestDetailInputPort
        def initialize(output_port:, user_id:, translator:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(pest_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PestPolicy.record_access_filter(user)
          pest_entity = @gateway.find_by_id(pest_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, pest_entity)
          dto = @gateway.authorized_pest_detail_output(pest_id)
          @output_port.on_success(dto)
        rescue Domain::Shared::Exceptions::RecordNotFound
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("pests.flash.not_found")))
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(@translator.t("pests.flash.no_permission")))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
