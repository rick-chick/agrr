# frozen_string_literal: true

module Domain
  module Crop
    module Interactors
      class CropDetailInteractor < Domain::Crop::Ports::CropDetailInputPort
        def initialize(output_port:, user_id:, show_detail_read_gateway:, user_lookup:)
          @output_port = output_port
          @show_detail_read_gateway = show_detail_read_gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(crop_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::CropPolicy.record_access_filter(user)
          show_detail_snapshot = @show_detail_read_gateway.find_show_detail_snapshot(crop_id: crop_id)
          crop_detail_dto = Mappers::CropShowDetailMapper.from_snapshot(show_detail_snapshot)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, crop_detail_dto.crop)
          @output_port.on_success(crop_detail_dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
