# frozen_string_literal: true

module Domain
  module Pesticide
    module Interactors
      class PesticideDetailInteractor < Domain::Pesticide::Ports::PesticideDetailInputPort
        def initialize(output_port:, user_id:, show_detail_read_gateway:, user_lookup:)
          @output_port = output_port
          @show_detail_read_gateway = show_detail_read_gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(pesticide_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::PesticidePolicy.record_access_filter(user)
          show_detail_snapshot = @show_detail_read_gateway.find_show_detail_snapshot(pesticide_id: pesticide_id)
          dto = Mappers::PesticideShowDetailMapper.from_snapshot(show_detail_snapshot)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, dto.pesticide)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
