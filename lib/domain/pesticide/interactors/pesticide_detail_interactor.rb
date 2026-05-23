# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractor < Domain::Pesticide::Ports::PesticideDetailInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          dto = @gateway.find_pesticide_show_detail(pesticide_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, dto.pesticide)
          html_display = Domain::Shared::Dtos::ResourceDisplayCapabilities.for_detail_record(user, dto.pesticide)
          enriched = Domain::Pesticide::Dtos::PesticideDetailOutput.new(
            pesticide: dto.pesticide,
            crop_name: dto.crop_name,
            pest_name: dto.pest_name,
            usage_constraint_snapshot: dto.usage_constraint_snapshot,
            application_detail_snapshot: dto.application_detail_snapshot,
            html_display: html_display
          )
          @output_port.on_success(enriched)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
