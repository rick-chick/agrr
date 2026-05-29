# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class FarmDetailInteractor < Domain::Farm::Ports::FarmDetailInputPort
        def initialize(output_port:, user_id:, gateway:, show_detail_read_gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @show_detail_read_gateway = show_detail_read_gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call(farm_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::FarmPolicy.record_access_filter(user)
          farm_entity = @gateway.find_by_id(farm_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, farm_entity)
          show_detail_snapshot = @show_detail_read_gateway.find_show_detail_snapshot(farm_id: farm_id)
          farm_detail_dto = Mappers::FarmShowDetailMapper.from_snapshot(show_detail_snapshot)
          @output_port.on_success(farm_detail_dto)
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
