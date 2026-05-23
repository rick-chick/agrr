# frozen_string_literal: true

module Domain
  module FieldCultivation
    module Interactors
      module Concerns
        module PlanFieldCultivationAuthorization
          private

          def assert_field_cultivation_plan_access!(user, gateway, field_cultivation_id, for_edit: false)
            context = gateway.find_plan_access_context(field_cultivation_id)
            if for_edit
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_edit_allowed!(user, context)
            else
              Domain::FieldCultivation::Policies::PlanFieldCultivationAccess.assert_view_allowed!(user, context)
            end
          end

          def assert_public_field_cultivation_plan_access!(gateway, field_cultivation_id)
            context = gateway.find_plan_access_context(field_cultivation_id)
            raise Domain::Shared::Policies::PolicyPermissionDenied unless context.plan_type_public
          end
        end
      end
    end
  end
end
