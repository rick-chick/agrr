# frozen_string_literal: true

module Domain
  module Pest
    module Interactors
      class PestListInteractor < Domain::Pest::Ports::PestListInputPort
        def initialize(output_port:, user_id:, gateway:, translator:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @translator = translator
          @user_lookup = user_lookup
        end

        def call
          user = @user_lookup.find(@user_id)
          filter = Domain::Shared::Policies::PestPolicy.index_list_filter(user)
          pests = @gateway.list_index_for_filter(filter)
          rows = Domain::Shared::Mappers::ReferencableListRowMapper.map_records(user, pests)
          @output_port.on_success(rows)
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
