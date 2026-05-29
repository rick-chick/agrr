# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      module Concerns
        module PlanFieldCultivationAuthorization
          private

          def assert_field_cultivation_plan_access!(user, access_snapshot, for_edit: false)
            if for_edit
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_edit_allowed!(user, access_snapshot)
            else
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_view_allowed!(user, access_snapshot)
            end
          end

          def assert_public_field_cultivation_plan_access!(access_snapshot)
            raise Domain::Shared::Policies::PolicyPermissionDenied unless access_snapshot.plan_type_public?
          end
        end
      end
    end
  end
end
