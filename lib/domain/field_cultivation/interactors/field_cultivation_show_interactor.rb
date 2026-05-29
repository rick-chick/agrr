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
          plan_access_snapshot = @gateway.find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
          if @user_id.present?
            user = @user_lookup.find(@user_id)
            assert_field_cultivation_plan_access!(user, plan_access_snapshot)
          else
            assert_public_field_cultivation_plan_access!(plan_access_snapshot)
          end
          api_summary_snapshot = @gateway.find_api_summary_by_field_cultivation_id(field_cultivation_id)
          api_summary = Mappers::FieldCultivationApiSummaryMapper.from_snapshot(api_summary_snapshot)
          @output_port.on_success(api_summary)
        rescue Domain::Shared::Policies::PolicyPermissionDenied
          @output_port.on_failure(Domain::Shared::Dtos::Error.new("Forbidden"))
        rescue Domain::Shared::Exceptions::RecordNotFound => e
          @output_port.on_failure(Domain::Shared::Dtos::Error.new(e.message))
        end
      end
    end
  end
end
