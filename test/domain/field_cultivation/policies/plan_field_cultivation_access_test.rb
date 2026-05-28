# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Policies
      class PlanFieldCultivationAccessTest < DomainLibTestCase
        test "allows view for public plan without authenticated user context" do
          context = public_field_cultivation_plan_context(1)
          user = domain_user_stub(id: 99)

          assert PlanFieldCultivationAccess.view_allowed?(user, context)
          PlanFieldCultivationAccess.assert_view_allowed!(user, context)
        end

        test "allows view and edit for plan owner on private plan" do
          context = private_field_cultivation_plan_context(1, plan_user_id: 5)
          user = domain_user_stub(id: 5)

          assert PlanFieldCultivationAccess.view_allowed?(user, context)
          PlanFieldCultivationAccess.assert_view_allowed!(user, context)
          PlanFieldCultivationAccess.assert_edit_allowed!(user, context)
        end

        test "denies view for non-owner on private plan" do
          context = private_field_cultivation_plan_context(1, plan_user_id: 5)
          user = domain_user_stub(id: 99)

          refute PlanFieldCultivationAccess.view_allowed?(user, context)
          assert_raises(Domain::Shared::Policies::PolicyPermissionDenied) do
            PlanFieldCultivationAccess.assert_view_allowed!(user, context)
          end
        end

        test "allows admin on private plan owned by another user" do
          context = private_field_cultivation_plan_context(1, plan_user_id: 5)
          admin = domain_user_stub(id: 99, admin: true)

          assert PlanFieldCultivationAccess.view_allowed?(admin, context)
        end
      end
    end
  end
end
