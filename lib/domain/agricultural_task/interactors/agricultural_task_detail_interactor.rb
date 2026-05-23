# frozen_string_literal: true

module Domain
  module AgriculturalTask
    module Interactors
      class AgriculturalTaskDetailInteractor < Domain::AgriculturalTask::Ports::AgriculturalTaskDetailInputPort
        def initialize(output_port:, user_id:, gateway:, user_lookup:)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(task_id)
          user = @user_lookup.find(@user_id)
          access_filter = Domain::Shared::Policies::AgriculturalTaskPolicy.record_access_filter(user)
          task_entity = @gateway.find_by_id(task_id)
          Domain::Shared::ReferenceRecordAuthorization.assert_view_allowed!(access_filter, task_entity)
          task_detail_dto = @gateway.authorized_agricultural_task_detail_output(task_id)
          @output_port.on_success(task_detail_dto)
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
