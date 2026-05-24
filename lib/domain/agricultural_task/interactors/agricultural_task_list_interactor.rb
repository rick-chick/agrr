# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskListInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskListInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(input_dto = nil)
          input_dto ||= Domain::AgriculturalTask::Dtos::AgriculturalTaskListInput.new(is_admin: false)

          user = @user_lookup.find(@user_id)
          filtered_tasks = list_tasks_for_input(input_dto, user_id: user.id)

          rows = Domain::Shared::Mappers::ReferencableListRowMapper.map_records(user, filtered_tasks)
          @output_port.on_success(rows)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end

        private

        def list_tasks_for_input(input_dto, user_id:)
          query = input_dto.query
          unless input_dto.is_admin
            return @gateway.list_user_owned_tasks(user_id: user_id, query: query)
          end

          case input_dto.filter
          when "user"
            @gateway.list_user_owned_tasks(user_id: user_id, query: query)
          when "reference"
            @gateway.list_reference_tasks(query: query)
          else
            @gateway.list_user_and_reference_tasks(user_id: user_id, query: query)
          end
        end
      end
    end
  end
end
