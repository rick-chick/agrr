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

          filtered_tasks = @gateway.list_for_index(
            user: user,
            is_admin: input_dto.is_admin,
            filter: input_dto.filter,
            query: input_dto.query
          )

          @output_port.on_success(filtered_tasks)
        rescue Domain::Shared::Policies::PolicyPermissionDenied => e
          @output_port.on_failure(e)
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end

        private
      end
    end
  end
end
