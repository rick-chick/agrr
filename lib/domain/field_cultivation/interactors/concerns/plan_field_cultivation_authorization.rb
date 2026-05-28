# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      module Concerns
        module PlanFieldCultivationAuthorization
          private

          def assert_field_cultivation_plan_access!(user, gateway, field_cultivation_id, for_edit: false)
            access_snapshot = gateway.find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
            if for_edit
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_edit_allowed!(user, access_snapshot)
            else
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_view_allowed!(user, access_snapshot)
            end
          end

          def assert_public_field_cultivation_plan_access!(gateway, field_cultivation_id)
            access_snapshot = gateway.find_plan_access_snapshot_by_field_cultivation_id(field_cultivation_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied unless access_snapshot.plan_type_public?
          end
        end
      end
    end
  end
end
