# frozen_string_literal: true

module Domain
  module Fertilize
    module Interactors
      class FertilizeListInteractor < Domain::Fertilize::Ports::FertilizeListInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(input_dto = nil)
          user = @user_lookup.find(@user_id)
          filter = Domain::Shared::Policies::FertilizePolicy.index_list_filter(user)
          filtered_fertilizes = @gateway.list_index_for_filter(filter)
          rows = Domain::Shared::Mappers::ReferencableListRowMapper.map_records(user, filtered_fertilizes)
          @output_port.on_success(rows)
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
