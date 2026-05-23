# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationUpdateInteractor
        include Concerns::PlanFieldCultivationAuthorization

        def initialize(output_port:, gateway:, user_id: nil, user_lookup: nil)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(input_dto)
          if @user_id.present?
            user = @user_lookup.find(@user_id)
            assert_field_cultivation_plan_access!(user, @gateway, input_dto.field_cultivation_id, for_edit: true)
          else
            assert_public_field_cultivation_plan_access!(@gateway, input_dto.field_cultivation_id)
          end
          dto = @gateway.update_field_cultivation_schedule(
            field_cultivation_id: input_dto.field_cultivation_id,
            start_date: input_dto.start_date,
            completion_date: input_dto.completion_date,
            public_plan: input_dto.public_plan?
          )
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        rescue Domain::Shared::Exceptions::RecordInvalid => e
          @output_port.on_failure(e)
        end
      end
    end
  end
end
