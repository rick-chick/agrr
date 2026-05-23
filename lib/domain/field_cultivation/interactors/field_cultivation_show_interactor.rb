# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      class FieldCultivationShowInteractor
        include Concerns::PlanFieldCultivationAuthorization

        def initialize(output_port:, gateway:, user_id: nil, user_lookup: nil)
          @output_port = output_port
          @gateway = gateway
          @user_id = user_id
          @user_lookup = user_lookup
        end

        def call(field_cultivation_id:)
          if @user_id.present?
            user = @user_lookup.find(@user_id)
            assert_field_cultivation_plan_access!(user, @gateway, field_cultivation_id)
          else
            assert_public_field_cultivation_plan_access!(@gateway, field_cultivation_id)
          end
          dto = @gateway.find_api_summary(field_cultivation_id: field_cultivation_id)
          @output_port.on_success(dto)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
